// dragevents: a tiny Hyprland plugin that reports window drags on Hyprland's
// event socket, whatever started them (title bar, Super+drag, middle-drag, or
// an app dragging itself by its own tab strip, like Edge):
//
//   windowdragstart>>ADDRESS,TILED        (TILED = 1 if it was a tile)
//   windowdragzone>>ZONE,X,Y,W,H          snap zone under the pointer changed:
//                                          top|left|right|none, and the area the
//                                          window would take there (work area of
//                                          that monitor, or its half)
//   windowdragpos>>X,Y                     pointer while over the top bar area
//                                          (for the taskbar's workspace numbers)
//   windowdragend>>ADDRESS,X,Y,MOVED     (cursor in layout coordinates;
//                                          MOVED = 1 if it travelled > 8px)
//
// Zones match ~/.config/omarchy/snap-tile-edge (edge_px = 48).
//
// The Omarchy taskbar (~/.config/omarchy/bar/modules/taskbar.qml) listens:
// a drop on a workspace number moves the window there, a drop on a screen
// edge snaps it (~/.config/omarchy/snap-tile-edge).
//
// It only reads Hyprland's drag state; it never cancels or changes input.
// Build: ~/.config/omarchy/hyprland-plugins/build. Loaded by
// ~/.config/omarchy/titlebars-load.

#define WLR_USE_UNSTABLE

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/EventManager.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/supplementary/DragController.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/state/MonitorState.hpp>

#include <format>

inline HANDLE PHANDLE = nullptr;

namespace {
    CHyprSignalListener g_moveListener;
    CHyprSignalListener g_buttonListener;

    PHLWINDOWREF        g_window;
    Vector2D            g_begin;
    bool                g_active = false;
    std::string         g_zone   = "none";
    Vector2D            g_lastPos{-1e6, -1e6};

    constexpr double    EDGE_PX = 48.0;

    // The window being moved by a drag right now, if any (resizes don't count).
    PHLWINDOW draggedWindow() {
        if (!g_layoutManager)
            return nullptr;
        const auto& controller = g_layoutManager->dragController();
        if (!controller || controller->mode() != MBIND_MOVE)
            return nullptr;
        const auto target = controller->target();
        return target ? target->window() : nullptr;
    }

    std::string addressOf(const PHLWINDOW& window) {
        return std::format("{:x}", (uintptr_t)window.get());
    }

    void post(const char* name, const std::string& data) {
        if (g_pEventManager)
            g_pEventManager->postEvent(SHyprIPCEvent{name, data});
    }

    PHLMONITOR monitorAt(const Vector2D& pos) {
        if (!State::monitorState())
            return nullptr;
        for (const auto& monitor : State::monitorState()->monitors()) {
            if (monitor && monitor->logicalBox().containsPoint(pos))
                return monitor;
        }
        return nullptr;
    }

    // Which snap zone the pointer is in, and the area a drop there gives.
    void updateZone(const Vector2D& pos) {
        std::string zone = "none";
        CBox        area;
        const auto  monitor = monitorAt(pos);
        if (monitor) {
            const auto whole = monitor->logicalBox();
            const auto work  = monitor->logicalBoxMinusReserved();
            if (pos.y <= whole.y + EDGE_PX) {
                zone = "top";
                area = work;
            } else if (pos.x <= whole.x + EDGE_PX) {
                zone = "left";
                area = CBox{work.x, work.y, work.w / 2.0, work.h};
            } else if (pos.x >= whole.x + whole.w - EDGE_PX) {
                zone = "right";
                area = CBox{work.x + work.w / 2.0, work.y, work.w / 2.0, work.h};
            }
            // Over the bar (the reserved strip above the work area): report the
            // pointer so the taskbar can light the workspace number under it.
            if (pos.y < work.y && (std::abs(pos.x - g_lastPos.x) >= 3 || std::abs(pos.y - g_lastPos.y) >= 3)) {
                g_lastPos = pos;
                post("windowdragpos", std::format("{},{}", (int)pos.x, (int)pos.y));
            }
        }
        if (zone == g_zone)
            return;
        g_zone = zone;
        post("windowdragzone", std::format("{},{},{},{},{}", zone, (int)area.x, (int)area.y, (int)area.w, (int)area.h));
    }

    // A drag shows up as motion while the drag controller holds a window.
    void onMouseMove(const Vector2D& pos) {
        const auto window = draggedWindow();
        if (g_active) {
            // Ended without a button release we saw (e.g. cancelled): forget it.
            if (!window) {
                g_active = false;
                if (g_zone != "none") {
                    g_zone = "none";
                    post("windowdragzone", "none,0,0,0,0");
                }
                return;
            }
            updateZone(pos);
            return;
        }
        if (!window)
            return;
        g_active  = true;
        g_window  = window;
        g_begin   = pos;
        g_zone    = "none";
        g_lastPos = {-1e6, -1e6};
        // Hyprland floats a dragged tile only once the drag threshold is
        // passed, so right now the window still says whether it's a tile.
        const bool tiled = !window->m_isFloating || g_layoutManager->dragController()->draggingTiled();
        post("windowdragstart", std::format("{},{}", addressOf(window), tiled ? 1 : 0));
        updateZone(pos);
    }

    // Any button coming up ends it. Other listeners (hyprbars) may already
    // have ended the drag by now, so this goes by what onMouseMove saw.
    void onMouseButton(const IPointer::SButtonEvent& e) {
        if (e.state == WL_POINTER_BUTTON_STATE_PRESSED || !g_active)
            return;
        g_active          = false;
        g_zone            = "none";
        const auto window = g_window.lock();
        if (!window || !g_pInputManager)
            return;
        const auto pos   = g_pInputManager->getMouseCoordsInternal();
        const bool moved = pos.distance(g_begin) > 8.0;
        post("windowdragend", std::format("{},{},{},{}", addressOf(window), (int)pos.x, (int)pos.y, moved ? 1 : 0));
    }
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    if (std::string{__hyprland_api_get_hash()} != std::string{__hyprland_api_get_client_hash()}) {
        HyprlandAPI::addNotification(PHANDLE, "[dragevents] Version mismatch: run ~/.config/omarchy/hyprland-plugins/build",
                                     CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[dragevents] Version mismatch");
    }

    g_moveListener   = Event::bus()->m_events.input.mouse.move.listen([](Vector2D pos, Event::SCallbackInfo&) { onMouseMove(pos); });
    g_buttonListener = Event::bus()->m_events.input.mouse.button.listen([](IPointer::SButtonEvent e, Event::SCallbackInfo&) { onMouseButton(e); });

    return {"dragevents", "Reports window drags on the event socket (windowdragstart/windowdragend).", "omarchy-desktop", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_moveListener.reset();
    g_buttonListener.reset();
}

CXXFLAGS ?= -O2
CXXFLAGS += -shared -fPIC -std=c++2b
# Without this, g++ marks some symbols "unique" and the library can never be
# unloaded: `hyprctl plugin unload` + `load` would silently keep the old code.
ifeq ($(CXX),g++)
CXXFLAGS += --no-gnu-unique
endif
INCLUDES = `pkg-config --cflags pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon`

dragevents.so: main.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) main.cpp -o $@

clean:
	rm -f dragevents.so

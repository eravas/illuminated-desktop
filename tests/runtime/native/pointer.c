// Real wlroots virtual pointer input for the private test compositor only.
#include <wayland-client.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "pointer-protocol.h"
static struct zwlr_virtual_pointer_manager_v1 *manager;
static void global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    (void)data;
    if (!strcmp(interface, "zwlr_virtual_pointer_manager_v1")) manager = wl_registry_bind(registry, name, &zwlr_virtual_pointer_manager_v1_interface, version < 2 ? version : 2);
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) { (void)data; (void)registry; (void)name; }
int main(int argc, char **argv) {
    if (argc < 4) return 2;
    uint32_t width=atoi(argv[1]), height=atoi(argv[2]);
    struct wl_display *display=wl_display_connect(NULL);
    if (!display) return 3;
    struct wl_registry *registry=wl_display_get_registry(display);
    const struct wl_registry_listener listener={global,removed};
    wl_registry_add_listener(registry,&listener,NULL); wl_display_roundtrip(display);
    if (!manager) return 4;
    struct zwlr_virtual_pointer_v1 *pointer=zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager,NULL);
    for(int i=3;i<argc;i++) {
        if (!strcmp(argv[i],"move") && i+2<argc) {
            uint32_t x=atoi(argv[++i]),y=atoi(argv[++i]);
            zwlr_virtual_pointer_v1_motion_absolute(pointer,0,x,y,width,height);
        } else if(!strcmp(argv[i],"down")) zwlr_virtual_pointer_v1_button(pointer,0,272,1);
        else if(!strcmp(argv[i],"up")) zwlr_virtual_pointer_v1_button(pointer,0,272,0);
        else if(!strcmp(argv[i],"right")) { zwlr_virtual_pointer_v1_button(pointer,0,273,1); zwlr_virtual_pointer_v1_button(pointer,0,273,0); }
        else if(!strcmp(argv[i],"scroll") && i+1<argc) zwlr_virtual_pointer_v1_axis(pointer,0,0,wl_fixed_from_int(atoi(argv[++i])));
        else if(!strcmp(argv[i],"wait") && i+1<argc) { usleep(atoi(argv[++i])*1000); continue; }
        else return 2;
        zwlr_virtual_pointer_v1_frame(pointer); wl_display_roundtrip(display); usleep(250000);
    }
    zwlr_virtual_pointer_v1_destroy(pointer); wl_display_roundtrip(display); wl_display_disconnect(display); return 0;
}

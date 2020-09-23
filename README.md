# Sustainable Softworks IPNetRouterX_App
Legacy IPNetRouterX project
NAT Firewall router with DHCP Server, Traffic Discovery, and TCP rate limiting.

Packet processing is handled in a separate NKE (Network Kernel Extension)
to provide interrupt driven single address space performance.
NAT translation and TCP connection table use AVL Trees for fast lookup.

Environment: MacOS X Cocoa/Obj-C through Snow Leopard (Intel 32-bit).

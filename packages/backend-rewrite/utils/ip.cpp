#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <WS2tcpip.h>
#include <WinSock2.h>
#include <iphlpapi.h>
#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")
#else
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#endif

#include "ip.h"

std::string getLocalIp() {
#ifdef _WIN32
    WSADATA wsaData;
    if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
        return "127.0.0.1";
    }

    ULONG bufferSize = 15000;
    std::string result = "127.0.0.1";

    IP_ADAPTER_ADDRESSES* adapters = static_cast<IP_ADAPTER_ADDRESSES*>(malloc(bufferSize));

    if(!adapters) {
        return result;
    }

    if (GetAdaptersAddresses(
        AF_INET,
        GAA_FLAG_SKIP_ANYCAST |
        GAA_FLAG_SKIP_MULTICAST |
        GAA_FLAG_SKIP_DNS_SERVER,
        nullptr,
        adapters,
        &bufferSize
    ) == NO_ERROR) {
        for (IP_ADAPTER_ADDRESSES* adapter = adapters; adapter != nullptr; adapter = adapter->Next) {
            if (adapter->IfType == IF_TYPE_SOFTWARE_LOOPBACK) {
                continue;
            }

            for (IP_ADAPTER_UNICAST_ADDRESS* ua = adapter->FirstUnicastAddress; ua != nullptr; ua = ua->Next) {
                sockaddr_in* sa = reinterpret_cast<sockaddr_in*>(ua->Address.lpSockaddr);

                char ipStr[INET_ADDRSTRLEN];
                if (inet_ntop(AF_INET, &sa->sin_addr, ipStr, sizeof(ipStr))) {
                    result = ipStr;
                    goto cleanup;
                }
            }
        }
    }

cleanup:
    free(adapters);
    WSACleanup();
    return result;

#else
    struct ifaddrs* ifaddr = nullptr;

    if (getifaddrs(&ifaddr) == -1) {
        return "127.0.0.1";
    }

    std::string result = "127.0.0.1";

    for (auto* ifa = ifaddr; ifa != nullptr; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr) {
            continue;
        }

        if (ifa->ifa_addr->sa_family == AF_INET) {
            auto* sa = reinterpret_cast<sockaddr_in*>(ifa->ifa_addr);
            std::string ip = inet_ntoa(sa->sin_addr);

            if (ip != "127.0.0.1") {
                result = ip;
                break;
            }
        }
    }

    freeifaddrs(ifaddr);
    return result;
#endif
}
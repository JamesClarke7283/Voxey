"""Loopback UDP relay for ENet tests: delay, jitter, loss and duplication.

Each client gets its own upstream socket, so the server still sees distinct
ENet peers. Only packets on the specified test ports are affected.
"""

import argparse
import heapq
import itertools
import selectors
import socket
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listen-port", type=int, required=True)
    parser.add_argument("--server-port", type=int, required=True)
    args = parser.parse_args()
    selector = selectors.DefaultSelector()
    listener = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    listener.bind(("127.0.0.1", args.listen_port))
    listener.setblocking(False)
    selector.register(listener, selectors.EVENT_READ, None)
    clients = {}
    pending = []
    order = itertools.count()
    packets = 0
    print("NETWORK PROXY READY: 25-75 ms delay, 4% loss, jitter and duplication", flush=True)
    while True:
        now = time.monotonic()
        while pending and pending[0][0] <= now:
            _, _, outgoing, address, packet = heapq.heappop(pending)
            outgoing.sendto(packet, address)
        timeout = max(0.0, pending[0][0] - now) if pending else 0.1
        for key, _ in selector.select(timeout):
            packet, address = key.fileobj.recvfrom(65535)
            if key.fileobj is listener:
                if address not in clients:
                    upstream = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    upstream.bind(("127.0.0.1", 0))
                    upstream.setblocking(False)
                    selector.register(upstream, selectors.EVENT_READ, address)
                    clients[address] = upstream
                outgoing = clients[address]
                destination = ("127.0.0.1", args.server_port)
            else:
                outgoing, destination = listener, key.data
            packets += 1
            if packets % 25 == 0:
                continue
            # Alternating delays reorder adjacent datagrams reproducibly.
            arrival = time.monotonic() + 0.025 + (packets * 19 % 51) / 1000.0
            heapq.heappush(pending, (arrival, next(order), outgoing, destination, packet))
            if packets % 37 == 0:
                heapq.heappush(pending, (arrival + 0.012, next(order), outgoing, destination, packet))


if __name__ == "__main__":
    main()

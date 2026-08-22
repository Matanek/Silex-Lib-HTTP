import socket
import sys


def receive_headers(connection: socket.socket) -> bytes:
    data = bytearray()
    while b"\r\n\r\n" not in data:
        chunk = connection.recv(4096)
        if not chunk:
            break
        data.extend(chunk)
        if len(data) > 65536:
            raise RuntimeError("proxy request headers exceed test limit")
    return bytes(data)


def main() -> None:
    port = int(sys.argv[1])
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(("127.0.0.1", port))
        listener.listen(2)
        print("ready", flush=True)
        for _ in range(2):
            connection, _ = listener.accept()
            with connection:
                request = receive_headers(connection).decode("iso-8859-1")
                lines = request.split("\r\n")
                print(lines[0], flush=True)
                for line in lines[1:]:
                    if line.lower().startswith("proxy-authorization:"):
                        print(line, flush=True)
                if lines[0].startswith("CONNECT "):
                    connection.sendall(
                        b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    )
                else:
                    connection.sendall(
                        b"HTTP/1.1 200 OK\r\nContent-Length: 8\r\nConnection: close\r\n\r\nproxy-ok"
                    )


if __name__ == "__main__":
    main()

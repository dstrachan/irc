#include <k.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

#define IRC_PORT "6667"
#define IRC_DISCONNECT_CALLBACK ".irc.priv.disconnectCallback"
#define IRC_MESSAGE_CALLBACK ".irc.priv.messageCallback"

int socket_desc;
char connected = 0;

K ircconnect(K x);
K ircdisconnect(K x);
K ircsend(K x);

int read_line(int sock, char buffer[])
{
    int length = 0;
    while (1) {
        char data;
        int result = recv(sock, &data, 1, 0);
        if ((result <= 0) || (data == EOF)) {
            return -1;
        }
        buffer[length++] = data;
        if (length >= 2 && buffer[length - 2] == '\r' && buffer[length - 1] == '\n') {
            buffer[length - 2] = '\0';
            return length;
        }
    }
}

K callback(int desc)
{
    char line[512];
    char *callback;
    if (read_line(desc, line) < 0) {
        ircdisconnect((K)0);
        callback = IRC_DISCONNECT_CALLBACK;
    } else {
        callback = IRC_MESSAGE_CALLBACK;
    }
    K data = kp(line);
    k(0, callback, data, (K)0);
    return (K)0;
}

K ircconnect(K x)
{
    if (connected) return kb(0);

    struct addrinfo hints;
    struct addrinfo *res;

    char *host;

    // Ensure x is of type symbol
    if (x->t == -KS) {
        host = x->s;
    } else {
        return krr("type");
    }

    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;

    if (getaddrinfo(host, IRC_PORT, &hints, &res) != 0) {
        freeaddrinfo(res);
        return kb(0);
    }

    // Create a socket
    socket_desc = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (socket_desc == -1) {
        freeaddrinfo(res);
        return kb(0);
    }

    // Connect to server
    if (connect(socket_desc, res->ai_addr, res->ai_addrlen) < 0) {
        freeaddrinfo(res);
        return kb(0);
    }

    // Set connected status
    connected = 1;

    // Register callback
    sd1(socket_desc, callback);

    freeaddrinfo(res);

    return kb(1);
}

K ircsend(K x)
{
    if (!connected) return kb(0);

    int i;
    char *message;

    // Ensure x is of type string
    if (x->t == KC) {
        message = malloc(x->n + 1);
        for (i = 0; i < x->n; ++i) {
            message[i] = kC(x)[i];
        }
        message[i] = '\0';
    } else {
        return krr("type");
    }

    // Send message
    send(socket_desc, message, strlen(message), 0);

    free(message);

    return kb(1);
}

K ircdisconnect(K x)
{
    if (!connected) return kb(0);

    // Remove callback and close socket
    sd0(socket_desc);

    // Set connected status
    connected = 0;

    return kb(1);
}

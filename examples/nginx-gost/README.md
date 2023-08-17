# Nginx with Gost TLS example

This is an example that shows how to create an nginx server that accepts only GOST TLS algorithms. It consists of the following componenets:

- **Server** - Nginx server that can only accept GOST TLS connections;
- **Proxy** - An Nginx that serves contents from server with cleartext.

## Running

```shell
docker-compose up
```

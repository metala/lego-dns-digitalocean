# Lego with DNS for DigitalOcean

> Let's Encrypt with DNS provider for DigitalOcean CDN endpoints

# Motivation

DigitalOcean does not support Let's Encrypt for delegated subdomains or CNAMEs, at the moment of writing. If you are using CloudFlare or different DNS provider, it leaves you with the only option to use custom certificate for your CDN endpoint.
This tool extends that option and allows you to acquire Let's Encrypt certificate for your endpoint CNAME records using [lego](://github.com/go-acme/lego) and DNS-01 challenge. The certificate is pushed to DigitalOcean and it is set as a custom certificate to your endpoint.
The tool is dockerized and is designed to run in a container. However, you can run it through `main.sh`, but it requires you to have `lego` installed in your system.

# Commands

```
$ docker run --rm metala/lego-dns-digitalocean help
Commands:
  run (default)   Setup or renew, whichever is necessary
  setup           Run to setup account and domain
  renew           Renew the domain and endpoint certificate
  loop            Execute run every $LOOP_INTERVAL (default: 1h)
  help            Show this help

Namespaces:
  endpoints       Endpoints namespace subcommands
  certificates    Certificates namespace subcommands

$ docker run --rm metala/lego-dns-digitalocean endpoints help
Endpoints namespace subcommands:
  ls                List all endpoints
  get               Get selected endpoint details
  get-cert          Get endpoint certficate
  set-cert CERTID   Set endpoint certficate
  refresh-cert      Verify and update endpoint certficate
  help              Show this help

$ docker run --rm metala/lego-dns-digitalocean certificates help
Certificates namespace subcommands:
  ls             List all certificates
  rm ID          Delete certificate with ID
  push           Push current certificate
  help           Show this help
```

# Example

Start with setting up an environment file `.env`:
```
LEGO_EMAIL=mail@example.com
LEGO_DOMAIN=subdomain.example.com
CLOUDFLARE_EMAIL=mail@example.com
CLOUDFLARE_API_KEY=
DIGITALOCEAN_API_KEY=
DIGITALOCEAN_ENDPOINT_ID=
LOOP_INTERVAL=1h
```

If you don't have the `DIGITALOCEAN_ENDPOINT_ID`, you can look it up using `endpoints ls` command.
```
$ docker run --rm -e "DIGITALOCEAN_API_KEY=<key>" metala/lego-dns-digitalocean endpoints ls
{
  "endpoints": [
    {
      "id": "3c327329-722b-4106-87c8-b3cf287beddd",
      "origin": "example.ams3.digitaloceanspaces.com",
      "endpoint": "example.ams3.cdn.digitaloceanspaces.com",
      "created_at": "2019-05-31T18:24:26Z",
      "ttl": 3600
    }
  ],
  "meta": {
    "total": 1
  }
}
```

Then you run the container with volume mounted at `/app/.lego` where the certificate is stored. You need to setup a volume for 
`/app/.lego`, otherwise you will recreate a new private key and you will hit the [Let's Encrypt rate limits](https://letsencrypt.org/docs/rate-limits/) very fast.
```
$ docker run --rm --env-file .env -v "$PWD/volume:/app/.lego" metala/lego-dns-digitalocean run

> Executing 'run'...
2019/06/01 17:36:09 No key found for account mail@example.com. Generating a P384 key.
2019/06/01 17:36:09 Saved key to /app/.lego/accounts/acme-v02.api.letsencrypt.org/mail@example.com/keys/mail@example.com.key
2019/06/01 17:36:10 [INFO] acme: Registering account for mail@example.com
<... truncated log ...>
2019/06/01 17:36:20 [INFO] [subdomain.example.com] acme: Cleaning DNS-01 challenge
2019/06/01 17:36:21 [INFO] [subdomain.example.com] acme: Validations succeeded; requesting certificates
2019/06/01 17:36:23 [INFO] [subdomain.example.com] Server responded with a certificate.
Refreshing endpoint certificate...
Pushing a certificate...
Setting endpoint certificate...
Updating endpoint '3c327329-722b-4106-87c8-b3cf287beddd' with certificate '63a741b1-6973-4a4f-a314-ae0737872bb5'...
{
	"endpoint": {
		"id": "3c327329-722b-4106-87c8-b3cf287beddd",
			"origin": "example.ams3.digitaloceanspaces.com",
			"endpoint": "example.ams3.cdn.digitaloceanspaces.com",
			"created_at": "2019-05-31T18:24:26Z",
			"certificate_id": "63a741b1-6973-4a4f-a314-ae0737872bb5",
			"custom_domain": "subdomain.example.com",
			"ttl": 3600
	}
}

```

# Running in a loop

The common way to use this tool is to run it forever in a loop. The command `loop` does just that, it executes the command `run` every `$LOOP_INTERVAL`, which defaults to `1h`.
```
$ docker run -d --rm --restart always --env-file .env -v "$PWD/volume:/app/.lego" metala/lego-dns-digitalocean loop
bf7a96e0b3d65afaf02091dd4df0fbe794bc0ab5e40a7e1a6389a4127e671b78
$ docker logs -f bf7a96e0b3d65afaf02091dd4df0fbe794bc0ab5e40a7e1a6389a4127e671b78
> Executing certificate update in a loop (interval: 1h )
> Running '/app/main.sh run'...
> Executing 'renew'...
2019/06/01 18:39:36 [subdomain.example.com] The certificate expires in 89 days, the number of days defined to perform the renewal is 30: no renewal.
> Next run will be on 'Sat Jun  1 19:39:36 UTC 2019' (in '1h').

```

# Contribution

If you want to contribute, go ahead.  You can open an issue or a pull request in GitHub and I will be happy to take a look.

# License

[MIT license](LICENSE.md)


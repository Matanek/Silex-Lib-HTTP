# HTTP

`HTTP` fournit un modèle HTTP/1.1 borné, des sessions clientes réutilisables
et un serveur d’applications. Le transport ne dépend pas du format du corps :
transmettez le texte UTF-8 à `JSON.parse`, `HTML.parse`, `YAML.parse` ou à un
autre package.

## Requêtes clientes

```sx
use HTTP.Client
use JSON

var response = try Client.get("https://example.com/api?limit=10")
try response.require_success()
let data = JSON.parse(try response.text())
```

Les opérations `get`, `head`, `delete`, `post`, `put` et `patch` couvrent les
requêtes courantes. `Client.send` accepte une `HTTP.Request` configurée.
`Response.is_success()` laisse la politique de statut à l’application ;
`Response.require_success()` fournit la forme stricte et récupérable.

Par défaut, le client suit au plus dix redirections. Il résout les valeurs
`Location` relatives, retire identifiants et cookies lors d’un changement
d’origine et refuse une rétrogradation HTTPS vers HTTP.

## Sessions réutilisables

Une `Client.Session` possède sa configuration et son pool de connexions.

```sx
var session = try Client.Session.create(
    Client.default_options().with_maximum_idle_connections_per_origin(4)
)
try session.set_default_header("Accept", "application/json")
try session.authenticate_bearer(token)
session.enable_cookies()

var exchange = try session.get("https://example.com/api")
print(exchange.final_url.text())
print(exchange.redirects.count())

try session.close()
```

Les en-têtes propres à une requête priment sur les valeurs par défaut. Les
cookies sont désactivés par défaut ; le stockage optionnel reste en mémoire et
limité à l’hôte. Une réponse progressive ne rend sa connexion au pool qu’après
lecture, copie ou abandon complet du corps.

## Délais, réseau et proxy

Les options clientes distinguent les délais de connexion, lecture, écriture et
le délai total partagé par les redirections. `with_public_network_only()`
rejette après résolution DNS les adresses locales, privées, link-local, non
spécifiées et multicast, puis recommence le contrôle à chaque redirection.

```sx
let options = Client.default_options()
    .with_read_timeout(5_000)
    .with_total_timeout(20_000)
    .with_public_network_only()
```

`Client.Proxy.parse` configure un proxy HTTP avec authentification Basic ou
Bearer. HTTP utilise une cible absolue ; HTTPS ouvre un tunnel `CONNECT` avant
TLS. `Proxy-Authorization` n’est jamais transmis à l’origine HTTPS.

## URL, formulaires et contenu

`Url.path`, `Url.query` et `Url.query_parameter` séparent le routage de la cible
brute. L’encodage des paramètres utilise les échappements UTF-8 et le décodage
rejette les séquences invalides.

```sx
let query = HTTP.encode_query([
    HTTP.QueryParameter(name:"search", value:"Silex HTTP"),
    HTTP.QueryParameter(name:"page", value:"2")
])
```

`HTTP.Form` traite les formulaires URL-encoded. `HTTP.Media` analyse types et
dispositions de contenu. `HTTP.Multipart.MultipartReader` lit progressivement
depuis un `STD.IO.Reader`. `HTTP.ContentCoding` décompresse explicitement
`gzip` et `deflate` avec une limite choisie par l’application.

## Serveur et routage

```sx
use HTTP
use HTTP.Server

func handle(request:@HTTP.Request) HTTP.Response {
    if request.path() == "/health" {
        return HTTP.Response.text(200, "{\"status\":\"ok\"}", "application/json")
    }
    return HTTP.Response.text(404, "Not found")
}

var server = try Server.listen("127.0.0.1", 8080)
try server.serve(handle)
```

`HTTP.Server.Router` associe méthodes et chemins. `:name` capture un segment et
un dernier `*name` capture le reste. Les middlewares s’exécutent dans l’ordre
avant la route, puis dans l’ordre inverse. Les limites par route et les réponses
standard `404`, `405` et `431` sont intégrées.

`serve_once` expose l’erreur d’une connexion contrôlée. `serve` isole les
connexions invalides et continue à accepter. `serve_while` et
`Application.stop()` assurent un arrêt gracieux. `with_workers` active un pool
borné de `STD.Threading.Executor`.

## Flux et garanties du protocole

`Client.download` copie dans un `STD.IO.Writer`. `send_stream` envoie un nombre
exact d’octets depuis un `STD.IO.Reader`. `open` et `open_request` rendent une
`IncomingResponse` lisible progressivement. Côté serveur, `IncomingBody` et
`ResponseWriter` gèrent les corps bornés, de longueur connue ou en chunks.

Le codec accepte les requêtes HTTP/1.1, les réponses HTTP/1.0 ou HTTP/1.1,
`Content-Length`, le transfert chunked et les réponses délimitées par fermeture.
Il borne en-têtes, trailers et corps, et rejette les cadrages ambigus, lignes LF
seules, upgrades et codages non pris en charge.

HTTPS passe par `STD.Network.TLS`. Sans fournisseur TLS vérifiant certificat et
hôte, le client renvoie une erreur `secure_transport` et ne bascule jamais en
clair.

## Développement

Depuis la racine du workspace Silex :

```text
silex link Packages/HTTP
silex test Packages/HTTP/Tests
Packages/HTTP/Tests/run-network-tests.sh
```

## Usage
The DGS framework provides a GraphQL client that can be used to retrieve data from a GraphQL endpoint.
The client has two components, each usable by itself, or in combination together.

* GraphQLClient - A HTTP client wrapper that provides easy parsing of GraphQL responses
* Query API codegen - Generate type-safe Query builders

## HTTP client wrapper

The GraphQL client wraps any HTTP client and provides easy parsing of GraphQL responses.
The client can be used against any GraphQL endpoint (it doesn't have to be implemented with the DGS framework),
but provides extra conveniences for parsing Gateway and DGS responses.
This includes support for the [Errors Spec](../error-handling.md).

To use the client, create an instance of `DefaultGraphQLClient`.

```java
GraphQLClient client = new DefaultGraphQLClient(url);
```

The `url` is the server url of the endpoint you want to call.
This url will be passed down to the callback discussed below.

Using the `GraphQLClient` a query can be executed.
The `executeQuery` method has four arguments:

1. The query String
2. An optional map of query variables
3. An optional operation name
3. An instance of `RequestExecutor`, typically provided as a lambda.

Because of the large number HTTP clients in use within Netflix, the GraphQLClient is decoupled from any particular HTTP client implementation.
Any HTTP client (RestTemplate, RestClient, OkHTTP, ....) can be used.
The operation name is useful in case of logging queries, or if you happen to have multiple queries as part of the same request.
The developer is responsible for making the actual HTTP call by implementing a `RequestExecutor`.
`RequestExecutor` receives the `url`, a map of `headers` and the request `body` as parameters, and should return an instance of `HttpResponse`.
Based on the HTTP response the GraphQLClient parses the response and provides easy access to data and errors.
The example below uses `RestTemplate`.

```
private RestTemplate dgsRestTemplate;

private static final String URL = "http://someserver/graphql";

private static final String QUERY = "{\n" +
            "  ticks(first: %d, after:%d){\n" +
            "    edges {\n" +
            "      node {\n" +
            "        route {\n" +
            "          name\n" +
            "          grade\n" +
            "          pitches\n" +
            "          location\n" +
            "        }\n" +
            "        \n" +
            "        userStars\n" +
            "      }\n" +
            "    }\n" +
            "  }\n" +
            "}";

public List<TicksConnection> getData() {
    DefaultGraphQLClient graphQLClient = new DefaultGraphQLClient(URL);
    GraphQLResponse response = graphQLClient.executeQuery(QUERY, new HashMap<>(), "TicksQuery", (url, headers, body) -> {
        /**
         * The requestHeaders providers headers typically required to call a GraphQL endpoint, including the Accept and Content-Type headers.
         * To use RestTemplate, the requestHeaders need to be transformed into Spring's HttpHeaders.
         */
        HttpHeaders requestHeaders = new HttpHeaders();
        headers.forEach(requestHeaders::put);
        
        /**
         * Use RestTemplate to call the GraphQL service. 
         * The response type should simply be String, because the parsing will be done by the GraphQLClient.
         */
        ResponseEntity<String> exchange = dgsRestTemplate.exchange(url, HttpMethod.POST, new HttpEntity(body, requestHeaders), String.class);
        
        /**
         * Return a HttpResponse, which contains the HTTP status code and response body (as a String).
         * The way to get these depend on the HTTP client.
         */
        return new HttpResponse(exchange.getStatusCodeValue(), exchange.getBody());
    }); 

    TicksConnection ticks = response.extractValueAsObject("ticks", TicksConnection.class);
    return ticks;
}
```

The `GraphQLClient` provides methods to parse and retrieve data and errors in a variety of ways.
Refer to the `GraphQLClient` JavaDoc for the complete list of supported methods.

                                                                                                                 
| method  | description  | example | 
|---|---|---|
| getData | Get the data as a Map<String, Object>  |  `Map<String,Object> data = response.getData()` |
| dataAsObject | Parse data as the provided class, using the Jackson Object Mapper  | `TickResponse data = response.dataAsObject(TicksResponse.class)` |
| extractValue | Extract values given a [JsonPath](https://github.com/json-path/JsonPath). The return type will be whatever type you expect, but depends on the JSON shape. For JSON objects, a Map is returned. Although this looks type safe, it really isn't. It's mostly useful for "simple" types like String, Int etc., and Lists of those types. | `List<String> name = response.extractValue("movies[*].originalTitle")` |
| extractValueAsObject | Extract values given a JsonPath and deserialize into the given class | `Ticks ticks = response.extractValueAsObject("ticks", Ticks.class)` |  
| extractValueAsObject | Extract values given a JsonPath and deserialize into the given TypeRef. Useful for Maps and Lists of a certain class. | `List<Route> routes = response.extractValueAsObject("ticks.edges[*].node.route", new TypeRef<List<Route>>(){})` |
| getRequestDetails | Extract a `RequestDetails` object. This only works if requestDetails was requested in the query, and against the Gateway. | RequestDetails requestDetails = `response.getRequestDetails()` |
| getParsed | Get the parsed `DocumentContext` for further JsonPath processing | `response.getDocumentContext()`|

### Errors

The GraphQLClient checks both for HTTP level errors (based on the response status code) and the `errors` block in a GraphQL response.
The GraphQLClient is compatible with the [Errors Spec](../error-handling.md) used by the Gateway and DGS, and makes it easy to extract error information such as the ErrorType.

For example, for following GraphQL response the GraphQLClient lets you easily get the ErrorType and ErrorDetail fields.
Note that the `ErrorType` is an enum as specified by the [Errors Spec](../error-handling.md).

```graphql
{
  "errors": [
    {
      "message": "java.lang.RuntimeException: test",
      "locations": [],
      "path": [
        "hello"
      ],
      "extensions": {
        "errorType": "BAD_REQUEST",
        "errorDetail": "FIELD_NOT_FOUND"
      }
    }
  ],
  "data": {
    "hello": null
  }
}
```

```java
assertThat(graphQLResponse.errors.get(0).extensions.errorType).isEqualTo(ErrorType.BAD_REQUEST)
assertThat(graphQLResponse.errors.get(0).extensions.errorDetail).isEqualTo("FIELD_NOT_FOUND")
```

## Type safe Query API

Based on a GraphQL schema a type safe query API can be generated for Java/Kotlin.
The generated API is a builder style API that lets you build a GraphQL query and it's projection (field selection).
Because the code gets re-generated when the schema changes, it helps catch errors in the query.
Because Java doesn't support multi-line strings (yet) it's also arguably a more readable way to specify a query.

If you own a DGS and want to generate a client for this DGS (e.g. for testing purposes) the client generation is just an extra property on the [Codegen configuration](../generating-code-from-schema.md).
Specify the following in your `build.gradle`.

```groovy
buildscript {
   dependencies{
      classpath 'netflix:graphql-dgs-codegen-gradle:latest.release'
   }
}

apply plugin: 'codegen-gradle-plugin'

generateJava{
   packageName = 'com.example.packagename' // The package name to use to generate sources
   generateClient = true
}
```

Code will be generated on build.
The generated code is in `build/generated`.

With codegen configured correctly, a builder style API will be generated when building the project.
Using the same query example as above, the query can be build using the generated builder API.

```
GraphQLQueryRequest graphQLQueryRequest =
                new GraphQLQueryRequest(
                    new TicksGraphQLQuery.Builder()
                        .first(first)
                        .after(after)
                        .build(),
                    new TicksConnectionProjectionRoot()
                        .edges()
                            .node()
                                .date()
                                .route()
                                    .name()
                                    .votes()
                                        .starRating()
                                        .parent()
                                    .grade());

String query = graphQLQueryRequest.serialize();
```

The `GraphQLQueryRequest` is a class from `graphql-dgs-client`.
The `TicksGraphQLQuery` and `TicksConnectionProjectionRoot` are generated.
After building the query, it can be serialized to a String, and executed using the GraphQLClient.

Note that the `edges` and `node` fields are because the example schema is using Relay pagination.

### Interface projections

When a field returns an interface, fields on the concrete types are specified using a fragment.

```graphql
type Query @extends {
    script(name: String): Script
}

interface Script {
    title: String
    director: String
    actors: [Actor]
}

type MovieScript implements Script {
    title: String
    director: String
    length: Int
}

type ShowScript implements Script {
    title: String
    director: String
    episodes: Int
}
```

```graphql
query { 
    script(name: "Top Secret") { 
        title 
        ... on MovieScript {
            length
        } 
    } 
}
```

This syntax is supported by the Query builder as well.

```java
 GraphQLQueryRequest graphQLQueryRequest =
    new GraphQLQueryRequest(
        new ScriptGraphQLQuery.Builder()
            .name("Top Secret")
            .build(),
        new ScriptProjectionRoot()
            .title()
            .onMovieScript()
                .length();                    
    );
```

### Building Federated Queries
You can use `GraphQLQueryRequest` along with `EntitiesGraphQLQuery` to generated federated queries. 
The API provides a type-safe way to construct the [_entities](https://www.apollographql.com/docs/apollo-server/federation/federation-spec/#resolve-requests-for-entities) query with the associated `representations` based on the input schema. 
The `representations` are passed in as a map of variables. Each representation class is generated based on the `key` fields defined  on the entity in your schema, along with the `__typename`. 
The `EntitiesProjectionRoot` is used to select query fields on the specified type.

For example, let us look at a schema that extends a `Movie` type:

```graphql
type Movie @key(fields: "movieId") @extends {
    movieId: Int @external
    script: MovieScript
}

type MovieScript  {
    title: String
    director: String
    actors: [Actor]
}

type Actor {
    name: String
    gender: String
    age: Int
}
```

With client code generation, you will now have a `MovieRepresentation` containing the key field, i.e., `movieId`, and the `__typename` field already set to type `Movie`. 
Now you can add each representation to the `EntitiesGraphQLQuery` as a `representations` variable.
You will also have a `EntitiesProjectionRoot` with `onMovie()` to select fields on `Movie` from.
Finally, you put them all together as a `GraphQLQueryRequest`, which you serialize into the final query string.
The map of `representations` variables is available via `getVariables` on the `EntitiesGraphQLQuery`.

Here is an example for the schema shown earlier:
```java
        EntitiesGraphQLQuery entitiesQuery = new EntitiesGraphQLQuery.Builder()
                    .addRepresentationAsVariable(
                            MovieRepresentation.newBuilder().movieId(1122).build()
                    )
                    .build();
        GraphQLQueryRequest request = new GraphQLQueryRequest(
                    entitiesQuery,
                    new EntitiesProjectionRoot().onMovie().movieId().script().title()
                    );

        String query  = request.serialize();
        Map<String, Object> representations = entitiesQuery.getVariables();
```


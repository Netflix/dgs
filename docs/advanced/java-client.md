## Usage
The DGS framework provides a GraphQL client that can be used to retrieve data from a GraphQL endpoint.
The client is also useful for integration testing a DGS.
The client has two components, each usable by itself, or in combination together.

* GraphQL Client - A HTTP client wrapper that provides easy parsing of GraphQL responses
* Query API codegen - Generate type-safe Query builders

The client has multiple interfaces and implementations for different needs.
The interfaces are the following:

* GraphQLClient - Client interface for blocking implementations. Only recommended when using a blocking HTTP client.
* MonoGraphQLClient - The same as GraphQLClient, but based on the reactive `Mono` interface meant for non-blocking implementations. Comes with an out-of-the-box WebClient implementation: `MonoGraphQLClient.createWithWebClient(...)`.
* ReactiveGraphQLClient - Client interface for streaming responses such as Subscriptions, where multiple results are expected. Based on the reactive `Flux` interface. Implemented by `SSESubscriptionGraphQLClient` and `WebSocketGraphQLClient`.

## GraphQL Client with WebClient

The easiest way to use the DGS GraphQL Client is to use the WebClient implementation.
WebClient is the recommended HTTP client in Spring, and is the best choice for most use cases, unless you have a specific reason to use a different HTTP client.
Because WebClient is Reactive, the client returns a `Mono` for all operations.

=== "Java"

```java
    //Configure a WebClient for your needs, e.g. including authentication headers and TLS.
    WebClient webClient = WebClient.create("http://localhost:8080/graphql");
    WebClientGraphQLClient client = MonoGraphQLClient.createWithWebClient(webClient);
    
    //The GraphQLResponse contains data and errors.
    Mono<GraphQLResponse> graphQLResponseMono = graphQLClient.reactiveExecuteQuery(query);
    
    //GraphQLResponse has convenience methods to extract fields using JsonPath.
    Mono<String> somefield = graphQLResponseMono.map(r -> r.extractValue("somefield"));
    
    //Don't forget to subscribe! The request won't be executed otherwise.
    somefield.subscribe();
```
    
=== "Kotlin"

```kotlin
    //Configure a WebClient for your needs, e.g. including authentication headers and TLS.
    val client = MonoGraphQLClient.createWithWebClient(WebClient.create("http://localhost:8080/graphql"))

    //Executing the query returns a Mono of GraphQLResponse.
    val result = client.reactiveExecuteQuery("{hello}").map { r -> r.extractValue<String>("hello") }

    //Don't forget to subscribe! The request won't be executed otherwise.
    somefield.subscribe();
```

The `reactiveExecuteQuery` method takes a query String as input, and optionally a Map of variables and an operation name.
Instead of using a query String, you can use code generation to create a type-safe query builder API.

The `GraphQLResponse` provides methods to parse and retrieve data and errors in a variety of ways.
Refer to the `GraphQLResponse` JavaDoc for the complete list of supported methods.


| method  | description  | example | 
|---|---|---|
| getData | Get the data as a Map<String, Object>  |  `Map<String,Object> data = response.getData()` |
| dataAsObject | Parse data as the provided class, using the Jackson Object Mapper  | `TickResponse data = response.dataAsObject(TicksResponse.class)` |
| extractValue | Extract values given a [JsonPath](https://github.com/json-path/JsonPath). The return type will be whatever type you expect, but depends on the JSON shape. For JSON objects, a Map is returned. Although this looks type safe, it really isn't. It's mostly useful for "simple" types like String, Int etc., and Lists of those types. | `List<String> name = response.extractValue("movies[*].originalTitle")` |
| extractValueAsObject | Extract values given a JsonPath and deserialize into the given class | `Ticks ticks = response.extractValueAsObject("ticks", Ticks.class)` |  
| extractValueAsObject | Extract values given a JsonPath and deserialize into the given TypeRef. Useful for Maps and Lists of a certain class. | `List<Route> routes = response.extractValueAsObject("ticks.edges[*].node.route", new TypeRef<List<Route>>(){})` |
| getRequestDetails | Extract a `RequestDetails` object. This only works if requestDetails was requested in the query, and against the Gateway. | RequestDetails requestDetails = `response.getRequestDetails()` |
| getParsed | Get the parsed `DocumentContext` for further JsonPath processing | `response.getDocumentContext()`|

The client can be used against any GraphQL endpoint (it doesn't have to be implemented with the DGS framework), but provides extra conveniences for parsing Gateway and DGS responses.
This includes support for the [Errors Spec](../error-handling.md).

### Headers

HTTP headers can easily be added to the request.

```java
WebClientGraphQLClient client = MonoGraphQLClient.createWithWebClient(webClient, headers -> headers.add("myheader", "test"));
```

By default, the client already sets the `Content-type` and `Accept` headers.

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


## Plug in your own HTTP client

Instead of using WebClient, you can also plug in your own HTTP client.
This is useful if you already have a configured client for your backend with authN/authZ, TLS, etc.
In this case you are responsible for making the actual request, but the GraphQL client wraps the HTTP client and provides easy parsing of GraphQL responses.

There are two interfaces that you can pick from:

* GraphQLClient: For blocking HTTP clients
* MonoGraphQLClient: For non-blocking HTTP clients

Both interfaces return a `GraphQLResponse` for each query execution, but `MonoGraphQLClient` wraps the result in a `Mono`, making it a better fit for non-blocking clients.
Create an instance by using the factory method on the interface.
This returns an instance of `CustomGraphQLClient` or `CustomMonoGraphQLClient`.
The implementations are named `Custom*` to indicate you need to provide handling of the actual HTTP request.

=== "Java"
    ```java
    CustomGraphQLClient client = GraphQLClient.createCustom(url,  (url, headers, body) -> {
        HttpHeaders httpHeaders = new HttpHeaders();
        headers.forEach(httpHeaders::addAll);
        ResponseEntity<String> exchange = restTemplate.exchange(url, HttpMethod.POST, new HttpEntity<>(body, httpHeaders),String.class);
        return new HttpResponse(exchange.getStatusCodeValue(), exchange.getBody());
    });
    
    GraphQLResponse graphQLResponse = client.executeQuery(query, emptyMap(), "SubmitReview");
    String submittedBy = graphQLResponse.extractValueAsObject("submitReview.submittedBy", String.class);
    ```
=== "Kotlin"
    ```kotlin
    //Configure your HTTP client
    val restTemplate = RestTemplate();
    
    val client = GraphQLClient.createCustom("http://localhost:8080/graphql") { url, headers, body ->
        //Prepare the request, e.g. set up headers.
        val httpHeaders = HttpHeaders()
        headers.forEach { httpHeaders.addAll(it.key, it.value) }
    
        //Use your HTTP client to send the request to the server.
        val exchange = restTemplate.exchange(url, HttpMethod.POST, HttpEntity(body, httpHeaders), String::class.java)
        
        //Transform the response into a HttpResponse
        HttpResponse(exchange.statusCodeValue, exchange.body)
    }
    
    //Send a query and extract a value out of the result.
    val result = client.executeQuery("{hello}").extractValue<String>("hello")
    ```

Alternatively, use `MonoGraphQLClient.createCustomReactive(...)` to create the reactive equivalent.
The provided `RequestExecutor` must now return `Mono<HttpResponse>`.

```java
CustomMonoGraphQLClient client = MonoGraphQLClient.createCustomReactive(url, (requestUrl, headers, body) -> {
    HttpHeaders httpHeaders = new HttpHeaders();
    headers.forEach(httpHeaders::addAll);
    ResponseEntity<String> exchange = restTemplate.exchange(url, HttpMethod.POST, new HttpEntity<>(body, httpHeaders),String.class);
    return Mono.just(new HttpResponse(exchange.getStatusCodeValue(), exchange.getBody(), exchange.getHeaders()));
});
Mono<GraphQLResponse> graphQLResponse = client.reactiveExecuteQuery(query, emptyMap(), "SubmitReview");
String submittedBy = graphQLResponse.map(r -> r.extractValueAsObject("submitReview.submittedBy", String.class)).block();
```

Note that in this example we just use `Mono.just` to create a Mono.
This doesn't make the call non-blocking.

### Migrating from DefaultGraphQLClient

In previous versions of the framework we provided the `DefaultGraphQLClient` class.
This has been deprecated for the following reasons:

* The "Default" in the name suggested that it should be the implementation for most use cases. However, the new WebClient implementation is a much better option now. Naming things is hard.
* The API required you to pass in the `RequestExecutor` for each query execution. This wasn't ergonomic for the new WebClient implementation, because no `RequestExecutor` is required.

If you want to migrate existing usage of `DefaultGraphQLClient` you can either use the WebClient implementation and get rid of your `RequestExecutor` entirely, or alternatively use `CustomGraphQLClient` / `CustomMonoGraphQLClient` which has almost the same API.
To migrate to `CustomGraphQLClient` you pass in your existing `RequestExecutor` to the `GraphQLClient.createCustom(url, requestExecutor)` factory method, and remove it from the `executeQuery` methods.

We plan to eventually remove the `DefaultGraphQLClient`, because its API is confusing.

## Type safe Query API

Based on a GraphQL schema a type safe query API can be generated for Java/Kotlin.
The generated API is a builder style API that lets you build a GraphQL query, and it's projection (field selection).
Because the code gets re-generated when the schema changes, it helps catch errors in the query.
It's arguably also more readable, although multiline String support in Java and Kotlin do mitigate that issue as well.

If you own a DGS and want to generate a client for this DGS (e.g. for testing purposes) the client generation is just an extra property on the [Codegen configuration](../generating-code-from-schema.md).
Specify the following in your `build.gradle`.

```groovy
// Using plugins DSL
plugins {
    id "com.netflix.dgs.codegen" version "[REPLACE_WITH_CODEGEN_PLUGIN_VERSION]"
}

generateJava{
   packageName = 'com.example.packagename' // The package name to use to generate sources
   generateClient = true
}
```

Code will be generated on build, and the generated code will be under `builder/generated`, which is added to the classpath by the plugin.

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

### Scalars in DGS Client

Custom scalars can be used in input types in GraphQL. Let's take the example of a `DateTimeScalar` (created in [Adding Custom Scalars](../scalars.md)).
In Java, we want to represent this as a `LocalDateTime` class. When sending the query, we somehow have to serialize this.
There are many ways to represent a date, so how do we make sure that we use the same representation as the server expects?

In this release we added an optional `scalars` argument to the `GraphQLQueryRequest` constructor. This is a `Map<Class<?>, Coercing<?,?>>` that maps the
Java class representing the input to an actual Scalar implementation. We will generate the query API with `DateTimeScalar` as follows:

```java
Map<Class<?>, Coercing<?, ?>> scalars = new HashMap<>();
scalars.put(java.time.LocalDateTime.class, new DateTimeScalar());

new GraphQLQueryRequest(
                ReviewsGraphQLQuery.newRequest().dateRange(new DateRange(LocalDate.of(2020, 1, 1), LocalDate.now())).build(),
                new ReviewsProjectionRoot().submittedDate().starScore(), scalars);
```

This way you can re-use exactly the same serialization code that you already have for your scalar implementation or one of the existing ones from - for example -
the `graphql-dgs-extended-scalars` module.

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

## Subscriptions

Subscriptions are supported through the `ReactiveGraphQLClient` interface.
The interface has two implementations:

* `WebSocketGraphQLClient`: For subscriptions over WebSockets
* `SSESubscriptionGraphQLClient`: For subscriptions over Server Sent Events (SSE)

Both implementations require the use of WebClient, and cannot be used with other HTTP clients (in contrast to the "normal" DGS client).
The clients return a `Flux` of `GraphQLResponse`.
Each `GraphQLResponse` represents a message pushed from the subscription, and contains `data` and `errors`.
It also offers convenience methods to parse data using JsonPath.

=== "Java"
    ```java
        WebClient webClient = WebClient.create("http://localhost:" + port);
        SSESubscriptionGraphQLClient client = new SSESubscriptionGraphQLClient("/subscriptions", webClient);
        Flux<GraphQLResponse> numbers = client.reactiveExecuteQuery("subscription {numbers}", Collections.emptyMap());

        numbers
            .mapNotNull(r -> r.extractValue("data.numbers"))
            .log()
            .subscribe();
    ```
=== "Kotlin"
    ```kotlin
    val webClient = WebClient.create("http://localhost:$port")
    val client = SSESubscriptionGraphQLClient("/subscriptions", webClient)
    val reactiveExecuteQuery = client.reactiveExecuteQuery("subscription {numbers}", emptyMap())

    reactiveExecuteQuery
        .mapNotNull { r -> r.data["numbers"] }
        .log()
        .subscribe()
    ```

In case the connection fails to set up, either because of a connection error, or because of an invalid query, a `WebClientResponseException` will be thrown.
Errors later on in the process will be errors in the stream.

Don't forget to `subscribe()` to the stream, otherwise the connection doesn't get started!

An example of using the client to write subscription integration tests is available [here](../subscriptions/#integration-testing-subscriptions).

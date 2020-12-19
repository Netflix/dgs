The DGS Code Generation plugin generates code during your project’s build process based on your Domain Graph Service’s GraphQL schema file.
The plugin generates the following:

* Data types for types, input types, enums and interfaces.
* A `DgsConstants` class containing the names of types and fields
* Example data fetchers
* A type safe query API that represents your queries

## Quick Start

To apply the plugin, update your project’s `build.gradle` file to include the following:
```groovy
// Using plugins DSL
plugins {
	id "com.netflix.dgs.codegen" version "4.0.10"
}
```

Alternatively, you can set up classpath dependencies in your buildscript:
```groovy
buildscript {
   dependencies{
      classpath 'com.netflix.graphql.dgs.codegen:graphql-dgs-codegen-gradle:latest.release'
   }
}

apply plugin: 'com.netflix.dgs.codegen'

generateJava{
   schemaPaths = ["${projectDir}/src/main/resources/schema"] // List of directories containing schema files
   packageName = 'com.example.packagename' // The package name to use to generate sources
   generateClient = true // Enable generating the type safe query API
}
```

The plugin adds a `generateJava` Gradle task that runs as part of your project’s build.
`generateJava` generates the code in the project’s `build/generated` directory.
This folder is automatically added to the project's classpath.
Types are available as part of the package specified by the <code><var>packageName</var>.types</code>, where you specify the value of <var>packageName</var> as a configuration in your `build.gradle` file.
Please ensure that your project’s sources refer to the generated code using<!-- http://go/pv http://go/use --> the specified package name.

`generateJava` generates the data fetchers and places them in `build/generated-examples`.

<div style="padding: 15px; border: 1px solid transparent; border-color: transparent; margin-bottom: 20px; border-radius: 4px; color: #8a6d3b;; background-color: #fcf8e3; border-color: #faebcc;">
 NOTE: generateJava does NOT add the data fetchers that it generates to your project’s sources.
 These fetchers serve mainly as a basic boilerplate code that require further implementation from you.
</div> 
   

You can exclude parts of the schema from code-generation by placing them in a different schema directory that is not specified<!-- http://go/pv --> as part of the `schemaPaths` for the plugin.
 
### Mapping existing types

Codegen tries to generate a type for each type it finds in the schema, with a few exceptions.

1. Basic scalar types - are mapped to corresponding Java/Kotlin types (String, Integer etc.)
2. Data and time types - are mapped to corresponding `java.time` classes
3. PageInfo and RelayPageInfo - are mapped to `graphql.relay` classes
4. Types mapped with a `typeMapping` configuration

When you have existing classes that you want to use instead of generating a class for a certain type, you can configure the plugin to do so using a `typeMapping`.
The `typeMapping` configuration is a `Map` where each key is a GraphQL type and each value is a fully qualified Java/Kotlin type.

```groovy
generateJava{
   typeMapping = ["MyGraphQLType": "com.mypackage.MyJavaType"]
}
```

## Generating Client APIs

The code generator can also create client API classes.
You can use these classes to query data from a GraphQL endpoint using Java. 
Java GraphQL clients are useful for server-to-server communication and testing. 

Code generation creates a <code><var>field-name</var>GraphQLQuery</code> for each Query and Mutation field. 
The <code>\*GraphQLQuery</code> query class contains fields for each parameter of the field. 
For each type returned by a Query or Mutation, code generation creates a <code>\*Projection</code>. 
A projection is a builder class that specifies which fields get returned. 

The following is an example usage of a generated API:

```java
GraphQLQueryRequest graphQLQueryRequest =
        new GraphQLQueryRequest(
            new TicksGraphQLQuery.Builder()
                .first(first)
                .after(after)
                .build(),
            new TicksConnectionProjection()
                .edges()
                    .node()
                        .date()
                        .route()
                            .name()
                            .votes()
                                .starRating()
                                .parent()
                            .grade());

```

This API was generated based on the following schema.
The `edges` and `node` types are because the schema uses pagination.
The API allows for a fluent style of writing queries, with almost the same feel of writing the query as a String, but with the added benefit of code completion and type safety.

```graphql
type Query @extends {
    ticks(first: Int, after: Int, allowCached: Boolean): TicksConnection
}

type Tick {
    id: ID
    route: Route
    date: LocalDate
    userStars: Int
    userRating: String
    leadStyle: LeadStyle
    comments: String
}

type Votes {
    starRating: Float
    nrOfVotes: Int
}

type Route {
    routeId: ID
    name: String
    grade: String
    style: Style
    pitches: Int
    votes: Votes
    location: [String]
}

type TicksConnection {
    edges: [TickEdge]
}

type TickEdge {
    cursor: String!
    node: Tick
}
```

## Sending a Query
A `GraphQLQueryRequest` can be serialized<!-- http://go/pv --> to JSON and sent<!-- http://go/pv --> to a GraphQL endpoint.
The following example uses RestTemplate with Metatron.

```java
@Metatron("spinnaker-app-name-goes-here")
private RestTemplate dgsRestTemplate;
private ObjectMapper mapper = new ObjectMapper();

private static HttpEntity<String> httpEntity(String request) {
    HttpHeaders headers = new HttpHeaders();
    headers.setAccept(Collections.singletonList(MediaType.APPLICATION_JSON));
    headers.setContentType(MediaType.APPLICATION_JSON);
    return new HttpEntity<>(request, headers);
}

Map<String, String> request = Collections.singletonMap("query", graphQLQueryRequest.serialize());

// Invoke REST call, and get the "ticks" from data.
JsonNode node = dgsRestTemplate.exchange(URL, HttpMethod.POST, httpEntity(mapper.writeValueAsString(request)),
        new ParameterizedTypeReference<JsonNode>() {
        }).getBody().get("data").get("ticks");

//Convert to the response type
TicksConnection ticks = mapper.convertValue(node, TicksConnection.class);
```



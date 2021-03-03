The DGS Code Generation plugin generates code during your project’s build process based on your Domain Graph Service’s GraphQL schema file.
The plugin generates the following:

* Data types for types, input types, enums and interfaces.
* A `DgsConstants` class containing the names of types and fields
* Example data fetchers
* A type safe query API that represents your queries

## Quick Start

Code generation is typically integrated in the build.
A Gradle plugin has always been available, and recently a Maven plugin was made [available](https://github.com/deweyjose/graphqlcodegen) by the community.

To apply the plugin, update your project’s `build.gradle` file to include the following:
```groovy
// Using plugins DSL
plugins {
	id "com.netflix.dgs.codegen" version "[REPLACE_WITH_CODEGEN_PLUGIN_VERSION]"
}
```

Alternatively, you can set up classpath dependencies in your buildscript:
```groovy
buildscript {
   dependencies{
      classpath 'com.netflix.graphql.dgs.codegen:graphql-dgs-codegen-gradle:[REPLACE_WITH_CODEGEN_PLUGIN_VERSION]'
   }
}

apply plugin: 'com.netflix.dgs.codegen'
```

Next, you need to add the task configuration as shown here:
```groovy
generateJava{
   schemaPaths = ["${projectDir}/src/main/resources/schema"] // List of directories containing schema files
   packageName = 'com.example.packagename' // The package name to use to generate sources
   generateClient = true // Enable generating the type safe query API
}
```

<div style="padding: 15px; border: 1px solid transparent; border-color: transparent; margin-bottom: 20px; border-radius: 4px; color: #8a6d3b;; background-color: #fcf8e3; border-color: #faebcc;">
 NOTE: Please use the latest version of the plugin, available <a href="https://github.com/Netflix/dgs-codegen/releases">here</a>
</div>    

The plugin adds a `generateJava` Gradle task that runs as part of your project’s build.
`generateJava` generates the code in the project’s `build/generated` directory.
Note that on a Kotlin project, the `generateJava` task generates Kotlin code by default (yes the name is confusing).
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
You can use these classes to query data from a GraphQL endpoint using Java, or in unit tests using the `QueryExecutor`.
The Java GraphQL Client is useful for server-to-server communication.
A GraphQL Java Client is [available](advanced/java-client) as part of the framework.

Code generation creates a <code><var>field-name</var>GraphQLQuery</code> for each Query and Mutation field. 
The <code>\*GraphQLQuery</code> query class contains fields for each parameter of the field. 
For each type returned by a Query or Mutation, code generation creates a <code>\*ProjectionRoot</code>. 
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

### Generating Query APIs for external services

Generating a Query API like above is very useful for testing your own DGS.
The same type of API can also be useful when interacting with another GraphQL service, where your code is a client of that service.
This is typically done using the [DGS Client](https://netflix.github.io/dgs/advanced/java-client/).

When you use code generation both for your own schema, and an internal schema, you might want different code generation configuration for both.
The recommendation is to create a separate module in your project containing the schema of the external service and the codegen configuration to just generate a Query API.
The following is example configuration that _only_ generates a Query API.

```groovy
generateJava {
    schemaPaths = ["${projectDir}/composed-schema.graphqls"]
    packageName = "some.other.service"
    generateClient = true
    generateDataTypes = false
    skipEntityQueries = true
    includeQueries = ["hello"]
    includeMutations = [""]
    shortProjectionNames = true
    maxProjectionDepth = 2
}
```

# Configuring code generation

Code generation has many configuration switches. 
The following table shows the Gradle configuration options, but the same options are available command line and in Maven as well.

| Configuration property | Description | Default Value | 
| ------------- | ------------- | ----------- |
| schemaPaths  | List of files/directories containing schemas | src/main/resources/schema |
| packageName | Base package name of generated code | |
| subPackageNameClient | Sub package name for generated Query API | client |
| subPackageNameDatafetchers | Sub package name for generated data fetchers | datafetcheres |
| subPackageNameTypes | Sub package name for generated data types | types |
| language | Either `java` or `kotlin` | Autodetected from project |
| typeMapping | A Map where each key is a GraphQL type, and the value the FQN of a Java class |  |
| generateBoxedTypes | Always use boxed types for primitives | false (boxed types are used only for nullable fields) |
| generateClient | Generate a Query API | false |
| generateDataTypes | Generate data types. Useful for only generating a Query API. Input types are still generated when `generateClient` is true. | true |
| generateDataTypes | Generate data types. Useful for only generating a Query API. Input types are still generated when `generateClient` is true. | true |
| generatedSourcesDir | Build directory for Gradle | build |
| outputDir | Sub directory of the `generatedSourcesDir` to generate into | generated |
| exampleOutputDir | Directory to generate datafetcher example code to | generated-examples |
| includeQueries | Generate Query API only for the given list of Query fields | All queries defined in schema |
| includeMutations | Generate Query API only for the given list of Mutation fields | All mutations defined in schema |
| skipEntityQueries | Disable generating Entity queries for federated types | false |
| shortProjectionNames | Shorten class names of projection types. These types are not visible to the developer. | false |
| maxProjectionDepth | Maximum projection depth to generate. Useful for (federated) schemas with very deep nesting | 10 |





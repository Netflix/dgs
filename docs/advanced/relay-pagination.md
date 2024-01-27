## Relay Pagination
The DGS framework supports dynamic generation of schema types for cursor based pagination based on the [relay spec](https://relay.dev/graphql/connections.htm).
When a type in the graphql schema is annotated with the `@connection` directive, the framework generates the corresponding `Connection` and `Edge` types, along with the common `PageInfo`.

This avoids boilerplate code around defining related Connection and Edge types in the schema for every type that needs to be paginated. 

!!!note
    The `@connection` directive only works for DGSs that are not required to register the static schema file with an external service (since the relay types are dynamically generated).
    For example, in a federated architecture involving a gateway, some gateway implementations may or may not recognize the `@connection` directive when working with a static schema file.


## Set up 
To enable the use of `@connection` directive for generating the schema for pagination, add the following module to dependencies in your build.gradle:

```
dependencies {
    implementation 'com.netflix.graphql.dgs:graphql-dgs-pagination'
}
```

Next, add the directive on the type you want to paginate.

```graphql
type Query {
      hello: MessageConnection
}
            
type Message @connection {
    name: String
}
```

Note that the `@connection` directive is defined automatically by the framework, so there is no need to add it to your schema file.

This results in the following relay types dynamically generated and added to the schema:

```graphql
"MessageConnection"
type MessageConnection {
  "Field edges"
  edges: [MessageEdge]
  "Field pageInfo"
  pageInfo: PageInfo
}

"MessageEdge"
type MessageEdge {
    "Field node"
    node: Message
    "Field cursor"
    cursor: String
}

"PageInfo"
type PageInfo {
    "Field hasPreviousPage"
    hasPreviousPage: Boolean!
    "Field hasNextPage"
    hasNextPage: Boolean!
    "Field startCursor"
    startCursor: String
    "Field endCursor"
    endCursor: String
}
```


You can now use the corresponding `graphql.relay` [types](https://www.javadoc.io/doc/com.graphql-java/graphql-java/16.2/graphql/relay/package-summary.html) for `Connection<T>`, `Edge<T>` and `PageInfo` to set up your datafetcher as shown here:

```java
@DgsData(parentType = "Query", field = "hello")
public Connection<Message> hello(DataFetchingEnvironment env) {
    return new SimpleListConnection<>(Collections.singletonList(new Message("This is a generated connection"))).get(env);
}
```

If your schema references a pagination type in a nested type, and you are using the code generation plugin, you will need some additional configuration, as described in the next section.

### Testing in Java
Don't forget to provide `DgsPaginationTypeDefinitionRegistry.class` and `PageInfo.class` when testing.

```java
@SpringBootTest(classes = {DgsAutoConfiguration.class, DgsPaginationTypeDefinitionRegistry.class, PageInfo.class})
class Test {
...

## Configuring Code Generation 
If you are using the [DGS Codegen Plugin](https://netflix.github.io/dgs/generating-code-from-schema/) for generating your data model, you will need to also add a type mapping for the relay types.
The code generation plugin does not process the `@connection` directive and therefore needs to be configured so the generated classes can refer to the mapped type.

For example,
```gradle
generateJava{
  ...
  typeMapping = ["MessageConnection": "graphql.relay.SimpleListConnection<Message>"]
}
```

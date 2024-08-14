# Leveraging GraphQLContext

As of graphql-java version [17](https://github.com/graphql-java/graphql-java/releases/tag/v17.0), [GraphQLContext](https://github.com/graphql-java/graphql-java/blob/master/src/main/java/graphql/GraphQLContext.java)
is now the approved context mechanism (replacing the previously used opaque Context) allowing passing of pertinent context
via key/value pairs to provide frameworks and userspace code the capability to contribute, share and leverage various 
pieces of context independent of each other.

Note that if you simply require interception/modification of request and response headers, you can use a `WebGraphQlInterceptor` provided by Spring GraphQL as described [here](intercepting-http-request-response.md).

To make this easily leverageable by DGS customers, a new interface has been provided for which any Spring Beans registered 
that implement the [`GraphQLContextContributor`](https://github.com/Netflix/dgs-framework/blob/master/graphql-dgs/src/main/kotlin/com/netflix/graphql/dgs/context/GraphQLContextContributor.kt) 
interface, their `contribute` method will be invoked before any normal instrumentation classes are invoked, allowing 
implementors to inspect anything provided via the DgsRequestData (i.e.: http headers), and set values on the provided 
GraphQLContext via a provided GraphQLContext.Builder.

#### Example:

```java  
@Component
public class ExampleGraphQLContextContributor implements GraphQLContextContributor {
    
    @Override
    public void contribute(@NotNull GraphQLContext.Builder builder, @Nullable Map<String, ?> extensions, @Nullable DgsRequestData dgsRequestData) {
        if (dgsRequestData != null && dgsRequestData.getHeaders() != null) {
            String contributedContextHeader = dgsRequestData.getHeaders().getFirst("x-context-contributor-header");
            if (CONTEXT_CONTRIBUTOR_HEADER_VALUE.equals("enabled")) {
                builder.put('exampleContributorEnabled', "true");
            }
        }
    }
}
```

You can now also use the GraphQLContext with the data loader as of DGS Framework 6.0.0:
```java
@DgsDataLoader(name = "exampleLoaderWithGraphQLContext")
public class ExampleLoaderWithGraphQLContext implements BatchLoaderWithContext<String, String> {
    @Override
    public CompletionStage<List<String>> load(List<String> keys, BatchLoaderEnvironment environment) {
        GraphQLContext graphQLContext = environment.getContext();
        return CompletableFuture.supplyAsync(() -> keys.stream().map((Function<String, String>) graphQLContext::get).collect(Collectors.toList()));
    }
}
```

# Request and Response Header Instrumentation
The DGS framework internally uses `GraphQL Java` and `Spring for GraphQL`.

If you need to modify the HTTP request and response headers, you can leverage the `WebGraphQlInterceptor` in [Spring for GraphQL](https://docs.spring.io/spring-graphql/reference/transports.html#server.interception) to accomplish this.
This provides a hook to update the request and response headers based using the `GraphQLContext`

#### Example:

```java  
@Component
public class MyInterceptor implements WebGraphQlInterceptor {
    @Override
    public Mono<WebGraphQlResponse> intercept(WebGraphQlRequest request, Chain chain) {
        String value = request.getHeaders().getFirst("myHeader");
        request.configureExecutionInput((executionInput, builder) ->
                builder.graphQLContext(Collections.singletonMap("myHeader", value)).build());
        return chain.next(request).doOnNext((response) -> {
            String value = response.getExecutionInput().getGraphQLContext().get("myContext");
            response.getResponseHeaders().add("MyContext", value);
        });
    }
}
```

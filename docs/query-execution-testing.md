The DGS framework allows you to write lightweight tests that partially bootstrap the framework, just enough to run queries.

### Example

Create some tests for the `hello` query that you created in the [Tutorial](tutorial.md).

Before writing tests, you need to add JUnit to the [Gradle] configuration.
This example uses JUnit 5:

```groovy
testImplementation("org.junit.jupiter:junit-jupiter-api:5.5.1")
testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:5.5.1")
testCompile 'com.netflix.spring:spring-boot-netflix-starter-test'
```

Create a test class with the following contents:

```java
import com.netflix.graphql.dgs.DgsQueryExecutor;
import com.netflix.graphql.dgs.autoconfig.DgsAutoConfiguration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(classes = {HelloDataFetcher.class, DgsAutoConfiguration.class},
                // The following line disables DGS reload behavior in tests
                properties = {"dgs.reload=false"})
class HelloDataFetcherTest {

    @Autowired
    DgsQueryExecutor queryExecutor;

    @Test
    void helloShouldIncludeName() {
        String message = queryExecutor.executeAndExtractJsonPath("{hello(name: \"DGS\")}", "data.hello");
        assertThat(message).isEqualTo("hello, DGS!");
    }

    @Test
    void helloShouldWorkWithoutName() {
        String message = queryExecutor.executeAndExtractJsonPath("{hello}", "data.hello");
        assertThat(message).isEqualTo("hello, stranger!");
    }
    
    @Test
    void helloShouldIncludeNameWithVariables() {
        String message = queryExecutor.executeAndExtractJsonPath("query Hello($name: String) { hello(name: $name)}", "data.hello", Maps.newHashMap("name", "DGS"));
        assertThat(message).isEqualTo("hello, DGS!");
    }
}
``` 

The `@SpringBootTest` annotation makes this a Spring test.
If you do not specify `classes` explicitly, Spring will start all components on the classpath.
This includes not only your code, but also the full Netflix ecosystem.
That really slows down tests, and most components aren’t necessary for testing!
It’s much better to explicitly list the classes that you need for this test.
In this case that’s just `HelloDataFetcher.class` and `DgsAutoConfiguration.class`.
`HelloDataFetcher` is obviously your code, and `DgsAutoConfiguration` starts the DGS-related components.

To run queries, inject `DgsQueryExecutor` in the test.
This interface has several methods to execute a query and get back the result.
It executes the exact same code as a query on the `/graphql` endpoint would, but you won’t have to deal with HTTP in your tests.
The `DgsQueryExecutor` methods accept JSON paths, so that the methods can easily extract just the data from the response that you’re interested in.
The JSON paths are supported by the open source [JsonPath library](https://github.com/json-path/JsonPath).

Run the tests from your IDE, and you’ll find that one of them is failing, because an empty name is not handled very nicely.
That should be an easy fix, and demonstrates how easy it is to write useful tests.

## Building GraphQL Queries for Tests
In the examples shown previously, we handcrafted the query string. 
This is simple enough for queries that are straightforward. 
However, constructing longer query strings can be tedious. 
For this, we can use the [GraphQLQueryRequest](./java-client.md) to build the graphql request in combination with the [code generation](./generating-code-from-schema.md) plugin to generate the classes needed to use the request builder. 
This provides a convenient type-safe way to build your queries.

To set up code generation to generate the required classes to use for building your queries, follow the instructions [here](./java-client.md#type-safe-query-api).

You will also need to add `com.netflix.graphql.dgs:graphql-dgs-client:latest.release` dependency to build.gradle.  

Now we can write a test that uses `GraphQLQueryRequest` to build the query and extract the response using `GraphQLResponse` for data fetchers for the following schema:
```graphql
type Query @extends {
    movieScript(movieId: ID): Movie
}

type Movie @key(fields: "movieId") @extends {
    movieId: ID!
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
The code generation plugin will generate the required POJOs, in addition to `MovieScriptGraphQLQuery` and a `MovieScriptProjection`.
The `MovieScriptGraphQLQuery` has a builder to represent the query with input types. The `MovieScriptProjection` lets you specify the fields you want in the response.

You can now set up your test like this:
```java
@Test
void scriptShouldIncludeTitle() throws IOException {
    GraphQLQueryRequest graphQLQueryRequest =
            new GraphQLQueryRequest(
                    new MovieScriptGraphQLQuery.Builder()
                            .movieId("111888999")
                            .build(),
                    new MovieScriptProjectionRoot().script().title().actors().name().age().parent().director()
            );
    // This generates "query {movieScript(movieId: "111888999"){ script { title actors { name age } director } } }"
    String query = graphQLQueryRequest.serialize();

    DocumentContext context = queryExecutor.executeAndGetDocumentContext(query);
    GraphQLResponse response = new GraphQLResponse(context.jsonString());
    Movie movie = response.extractValueAsObject("data.movieScript", Movie.class);
    assertThat(movie.getScript().getTitle()).isEqualTo("Top Secret");
}
```

The `GraphQLQueryRequest` is available as part of the [graphql-client module](./java-client.md) and is used to build the query string, and wrap the response respectively. You can also refer to the GraphQLClient JavaDoc for more details on the list of supported methods.

## Mocking External Service Calls in Tests

It’s not uncommon for a data fetcher to talk to external systems: either a database or a remote service.
If it does so within a test, this adds two problems:

1. It adds latency; your tests are going to run slower when they make a lot of external calls.
2. It adds flakiness: Did your code introduce a bug, or did something go wrong in the external system?

In many cases it’s better to mock these external services.
Spring already has good support for doing so with the [@Mockbean](https://docs.spring.io/spring-boot/docs/current/api/org/springframework/boot/test/mock/mockito/MockBean.html) annotation, which you can leverage in your [DGS] tests.

### Example
Introduce a fictional service client `GreeterService` to the project (in the real world this could be a [gRPC] client):

```java
public interface GreeterService {
    String randomGreeting(String name);
}

@Component
public class FakeGreeterServiceImpl implements GreeterService {
    @Override
    public String randomGreeting(String name) {
        throw new RuntimeException("This is not a real client!");
    }
}
```

The hello data fetcher should use this new `GreeterService`:

```java
@DgsComponent
public class HelloDataFetcher {
    @Autowired
    GreeterService greeterService;

    @DgsData(parentType = "Query", key = "hello")
    public String hello(DataFetchingEnvironment dfe) {

        String name = dfe.getArgument("name");

        return greeterService.randomGreeting(name);
    }
}
```

All tests now fail, since the `FakeGreeterServiceImpl` isn’t included in the `classes` definition of `@SpringBootTest`. 
If you include it, the tests fail with the `RuntimeException` that’s thrown from the `randomGreeting()` method.
To add a mock to make the tests work again, add the following code to the test:

```java
@MockBean
GreeterService greeterService;

@Before
void setup() {
    when(greeterService.randomGreeting(anyString())).thenAnswer(invocation -> "Mocked greeting, " + invocation.getArgument(0));
}
```

## Testing Exceptions

The tests you wrote so far are mostly happy paths.
Failure scenarios are also easy to test.
Try a query with two fields that both return an error:

```java
@Test
void getQueryWithMultipleExceptions() {
    try {
        queryExecutor.executeAndExtractJsonPath("{withRuntimeException, withGraphqlException}", "data.greeting");
        fail("Exception should have been thrown");
    } catch(QueryException ex) {
        assertThat(ex.getErrors().get(0).getMessage()).isEqualTo("java.lang.RuntimeException: That's broken!");
        assertThat(ex.getErrors().get(1).getMessage()).isEqualTo("graphql.GraphQLException: that's not going to work!");
        assertThat(ex.getMessage()).isEqualTo("java.lang.RuntimeException: That's broken!, graphql.GraphQLException: that's not going to work!");
        assertThat(ex.getErrors().size()).isEqualTo(2);
    }
}
```

When an error happens while executing<!-- http://go/pv --> the query, the errors are wrapped<!-- http://go/pv --> and thrown<!-- http://go/pv --> in a `QueryException`.
This allows you to easily inspect the error.
The `message` of the `QueryException` is the concatenation of all the errors.
The `getErrors()` method gives access to the individual errors for further inspection. 

--8<-- "docs/reference_links"


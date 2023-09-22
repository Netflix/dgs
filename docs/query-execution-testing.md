The DGS framework allows you to write lightweight tests that partially bootstrap the framework, just enough to run queries.

### Example

Before writing tests, make sure that JUnit is enabled.
If you created a project with Spring Initializr this configuration should already be there.

=== "Gradle"
    ```groovy
    dependencies {
        testImplementation 'org.springframework.boot:spring-boot-starter-test'
    }

    test {
        useJUnitPlatform()
    }
    ```
=== "Gradle Kotlin"
    ```kotlin
    tasks.withType<Test> {
        useJUnitPlatform()
    }
    ```
=== "Maven"
    ```xml
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-test</artifactId>
        <scope>test</scope>
    </dependency>
    ```

Create a test class with the following contents to test the `ShowsDatafetcher` from the [getting started](../getting-started) example.

=== "Java"
    ```java
    import com.netflix.graphql.dgs.DgsQueryExecutor;
    import com.netflix.graphql.dgs.autoconfig.DgsAutoConfiguration;
    import org.junit.jupiter.api.Test;
    import org.springframework.beans.factory.annotation.Autowired;
    import org.springframework.boot.test.context.SpringBootTest;

    import java.util.List;

    import static org.assertj.core.api.Assertions.assertThat;


    @SpringBootTest(classes = {DgsAutoConfiguration.class, ShowsDatafetcher.class})
    class ShowsDatafetcherTest {

        @Autowired
        DgsQueryExecutor dgsQueryExecutor;

        @Test
        void shows() {
            List<String> titles = dgsQueryExecutor.executeAndExtractJsonPath(
                    " { shows { title releaseYear }}",
                    "data.shows[*].title");

            assertThat(titles).contains("Ozark");
        }
    }
    ```
=== "Kotlin"
    ```kotlin
    import com.netflix.graphql.dgs.DgsQueryExecutor
    import com.netflix.graphql.dgs.autoconfig.DgsAutoConfiguration
    import org.assertj.core.api.Assertions.assertThat
    import org.junit.jupiter.api.Test
    import org.springframework.beans.factory.annotation.Autowired
    import org.springframework.boot.test.context.SpringBootTest

    @SpringBootTest(classes = [DgsAutoConfiguration::class, ShowsDataFetcher::class])
    class ShowsDataFetcherTest {

        @Autowired
        lateinit var dgsQueryExecutor: DgsQueryExecutor

        @Test
        fun shows() {
            val titles : List<String> = dgsQueryExecutor.executeAndExtractJsonPath("""
                {
                    shows {
                        title
                        releaseYear
                    }
                }
            """.trimIndent(), "data.shows[*].title")

            assertThat(titles).contains("Ozark")
        }
    }
    ```

The `@SpringBootTest` annotation makes this a Spring test.
If you do not specify `classes` explicitly, Spring will start all components on the classpath.
For a small application this is fine, but for applications with components that are "expensive" to start we can speed up the test by only adding the classes we need for the test.
In this case we need to include the DGS framework itself using the `DgsAutoConfiguration` class, and the `ShowsDatafetcher`.

!!!info "Testing data fetchers that use WebMVC annotations such as @RequestHeader"
    If you are using features specific to WebMvc stack, such as `@RequestHeader`, you will also need to specify `DgsWebMvcAutoConfiguration` in the list of classes.

To execute queries, inject `DgsQueryExecutor` in the test.
This interface has several methods to execute a query and get back the result.
It executes the exact same code as a query on the `/graphql` endpoint would, but you won’t have to deal with HTTP in your tests.
The `DgsQueryExecutor` methods accept JSON paths, so that the methods can easily extract just the data from the response that you’re interested in.
The `DgsQueryExecutor` also includes methods (e.g. `executeAndExtractJsonPathAsObject`) to deserialize the result to a Java class, which uses Jackson under the hood.
The JSON paths are supported by the open source [JsonPath library](https://github.com/json-path/JsonPath).

Write a few more tests, for example to verify the behavior with using the `titleFilter` of `ShowsDatafetcher`.
You can run the tests from the IDE, or from Gradle/Maven, just like any JUnit test.

## Building GraphQL Queries for Tests
In the examples shown previously, we handcrafted the query string.
This is simple enough for queries that are small and straightforward.
However, constructing longer query strings can be tedious, specially in Java without support for multi-line Strings.
For this, we can use the [GraphQLQueryRequest](advanced/java-client.md) to build the graphql request in combination with the [code generation](./generating-code-from-schema.md) plugin to generate the classes needed to use the request builder.
This provides a convenient type-safe way to build your queries.

To set up code generation to generate the required classes to use for building your queries, follow the instructions [here](advanced/java-client.md#type-safe-query-api).

Now we can write a test that uses `GraphQLQueryRequest` to build the query and extract the response using `GraphQLResponse`.

=== "Java"
    ```java
    @Test
    public void showsWithQueryApi() {
        GraphQLQueryRequest graphQLQueryRequest = new GraphQLQueryRequest(
                new ShowsGraphQLQuery.Builder().titleFilter("Oz").build(),
                new ShowsProjectionRoot().title()
        );

        List<String> titles = dgsQueryExecutor.executeAndExtractJsonPath(graphQLQueryRequest.serialize(), "data.shows[*].title");
        assertThat(titles).containsExactly("Ozark");
    }
    ```
=== "Kotlin"
    ```kotlin
    @Test
    fun showsWithQueryApi() {
        val graphQLQueryRequest = GraphQLQueryRequest(
            ShowsGraphQLQuery.Builder()
                .titleFilter("Oz")
                .build(),
            ShowsProjectionRoot().title())

        val titles = dgsQueryExecutor.executeAndExtractJsonPath<List<String>>(graphQLQueryRequest.serialize(), "data.shows[*].title")
        assertThat(titles).containsExactly("Ozark")
    }
    ```

The `GraphQLQueryRequest` is available as part of the [graphql-client module](advanced/java-client.md) and is used to build the query string, and wrap the response respectively.
You can also refer to the GraphQLClient JavaDoc for more details on the list of supported methods.

## Mocking External Service Calls in Tests

It’s not uncommon for a data fetcher to talk to external systems such as a database or a gRPC service.
If it does so within a test, this adds two problems:

1. It adds latency; your tests are going to run slower when they make a lot of external calls.
2. It adds flakiness: Did your code introduce a bug, or did something go wrong in the external system?

In many cases it’s better to mock these external services.
Spring already has good support for doing so with the [@Mockbean](https://docs.spring.io/spring-boot/docs/current/api/org/springframework/boot/test/mock/mockito/MockBean.html) annotation, which you can leverage in your DGS tests.

### Example
Let's update the `Shows` example to load shows from an external data source, instead of just returning a fixed list.
For the sake of the example we'll just move the fixed list of shows to a new class that we'll annotate `@Service`.
The data fetcher is updated to use the injected `ShowsService`.

=== "Java"
    ```java
    public interface ShowsService {
        List<Show> shows();
    }

    @Service
    public class ShowsServiceImpl implements ShowsService {
        @Override
        public List<Show> shows() {
            return List.of(
                new Show("Stranger Things", 2016),
                new Show("Ozark", 2017),
                new Show("The Crown", 2016),
                new Show("Dead to Me", 2019),
                new Show("Orange is the New Black", 2013)
            );
        }
    }
    ```
=== "Kotlin"
    ```kotlin
    interface ShowsService {
        fun shows(): List<ShowsDataFetcher.Show>
    }

    @Service
    class BasicShowsService : ShowsService {
        override fun shows(): List<ShowsDataFetcher.Show> {
            return listOf(
                ShowsDataFetcher.Show("Stranger Things", 2016),
                ShowsDataFetcher.Show("Ozark", 2017),
                ShowsDataFetcher.Show("The Crown", 2016),
                ShowsDataFetcher.Show("Dead to Me", 2019),
                ShowsDataFetcher.Show("Orange is the New Black", 2013)
            )
        }
    }

    @DgsComponent
    class ShowsDataFetcher {
        @Autowired
        lateinit var showsService: ShowsService

        @DgsData(parentType = "Query", field = "shows")
        fun shows(@InputArgument("titleFilter") titleFilter: String?): List<Show> {
            return if (titleFilter != null) {
                showsService.shows().filter { it.title.contains(titleFilter) }
            } else {
                showsService.shows()
            }
        }
    }
    ```

For the sake of the example the shows are still in-memory, imagine that the service would actually call out to an external data store.
Let's try to mock this service in the test!

=== "Java"
    ```java
    @SpringBootTest(classes = {DgsAutoConfiguration.class, ShowsDataFetcher.class})
    public class ShowsDataFetcherTests {

        @Autowired
        DgsQueryExecutor dgsQueryExecutor;

        @MockBean
        ShowsService showsService;

        @BeforeEach
        public void before() {
            Mockito.when(showsService.shows()).thenAnswer(invocation -> List.of(new Show("mock title", 2020)));
        }

        @Test
        public void showsWithQueryApi() {
            GraphQLQueryRequest graphQLQueryRequest = new GraphQLQueryRequest(
                    new ShowsGraphQLQuery.Builder().build(),
                    new ShowsProjectionRoot().title()
            );

            List<String> titles = dgsQueryExecutor.executeAndExtractJsonPath(graphQLQueryRequest.serialize(), "data.shows[*].title");
            assertThat(titles).containsExactly("mock title");
        }
    }
    ```
=== "Kotlin"
    ```kotlin
    @SpringBootTest(classes = [DgsAutoConfiguration::class, ShowsDataFetcher::class])
    class ShowsDataFetcherTest {

        @Autowired
        lateinit var
        dgsQueryExecutor:DgsQueryExecutor

        @MockBean
        lateinit var
        showsService:ShowsService

        @BeforeEach

        fun before() {
            Mockito.`when`(showsService.shows()).thenAnswer {
                listOf(ShowsDataFetcher.Show("mock title", 2020))
            }
        }

        @Test
        fun shows() {
            val titles :List<String> =dgsQueryExecutor.executeAndExtractJsonPath("""
                        {
                            shows {
                                title
                                releaseYear
                            }
                        }
                    """.trimIndent(), "data.shows[*].title")

            assertThat(titles).contains("mock title")
        }
    }
    ```

## Testing Exceptions

The tests you wrote so far are mostly happy paths.
Failure scenarios are also easy to test.
We use the mocked example from above to force an exception.

=== "Java"
    ```java
    @Test
    void showsWithException() {
    Mockito.when(showsService.shows()).thenThrow(new RuntimeException("nothing to see here"));
        ExecutionResult result = dgsQueryExecutor.execute(" { shows { title releaseYear }}");
        assertThat(result.getErrors()).isNotEmpty();
        assertThat(result.getErrors().get(0).getMessage()).isEqualTo("java.lang.RuntimeException: nothing to see here");
    }
    ```
=== "Kotlin"
    ```kotlin
    @Test
    fun showsWithException() {
        Mockito.`when`(showsService.shows()).thenThrow(RuntimeException("nothing to see here"))

        val result = dgsQueryExecutor.execute("""
            {
                shows {
                    title
                    releaseYear
                }
            }
        """.trimIndent())

        assertThat(result.errors).isNotEmpty
        assertThat(result.errors[0].message).isEqualTo("java.lang.RuntimeException: nothing to see here")
    }
    ```

When an error happens while executing the query, the errors are wrapped in a `QueryException`.
This allows you to easily inspect the error.
The `message` of the `QueryException` is the concatenation of all the errors.
The `getErrors()` method gives access to the individual errors for further inspection.

## Testing with Client

If you are interested in testing the web layer as well, you can use the [Java GraphQL Client](advanced/java-client.md).
Following is a simple example:

=== "Java"
    ```java
    import com.netflix.graphql.dgs.client.GraphQLResponse;
    import com.netflix.graphql.dgs.client.MonoGraphQLClient;
    import org.junit.jupiter.api.Test;
    import org.springframework.boot.test.context.SpringBootTest;
    import org.springframework.boot.web.server.LocalServerPort;
    import org.springframework.web.reactive.function.client.WebClient;
    
    import java.util.List;
    
    import static org.junit.jupiter.api.Assertions.assertTrue;
    
    @SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
    class ShowsDatafetcherTest {
    final MonoGraphQLClient monoGraphQLClient;
    
        public ShowsDatafetcherTest(@LocalServerPort Integer port) {
            WebClient webClient = WebClient.create("http://localhost:" + port.toString() + "/graphql");
            this.monoGraphQLClient = MonoGraphQLClient.createWithWebClient(webClient);
        }
    
        @Test
        void shows() {
            String query = "{ shows { title releaseYear }}";
    
            // Read more about executeQuery() at https://netflix.github.io/dgs/advanced/java-client/
            GraphQLResponse response =
                    monoGraphQLClient.reactiveExecuteQuery(query).block();
    
            List<?> titles = response.extractValueAsObject("shows[*].title", List.class);
    
            assertTrue(titles.contains("Ozark"));
        }
    }
    ```

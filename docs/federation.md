
Federation is based on the [Federation spec](https://www.apollographql.com/docs/apollo-server/federation/federation-spec/).

A DGS is federation-compatible out of the box with the ability to reference and extend federated types.

!!!tip "There is more federation documentation available"
    * Read the [Federation Spec](https://www.apollographql.com/docs/apollo-server/federation/federation-spec/).
    * Check out [Federated Testing](./advanced/federated-testing.md) to learn how to write tests for federated queries.


## Federation Example DGS

This is a DGS example that demonstrates how to implement a federated type, and test federated queries.
The source code in this guide comes from the [Federation example app](https://github.com/Netflix/dgs-federation-example).
We highly recommend cloning the project and use the IDE while following this guide.

The example project has the following set up:

1. A federated gateway is set up using Apollo's federation gateway libraries.
2. The [Shows DGS](https://github.com/Netflix/dgs-federation-example/tree/master/shows-dgs) defines and owns the `Show` type.
3. The [Reviews DGS](https://github.com/Netflix/dgs-federation-example/tree/master/reviews-dgs) adds a `reviews` field to the `Show` type.


!!!info
    If you are completely new to the DGS framework, please take a look at the [DGS Getting Started](./getting-started.md) guide, which also contains an introduction video.
    The remainder of the guide on this page assumes basic GraphQL and DGS knowledge, and focuses on more advanced use cases.

### Defining a federated type
The Shows DGS defines the `Show` type with fields id, title and releaseYear. 
Note that the `id` field is marked as the key. 
The example has one key, but you can have multiple keys as well `@key(fields:"fieldA fieldB")`
This indicates to the gateway that the `id` field will be used for identifying the corresponding Show in the Shows DGS and must be specified for federated types.
```graphql
type Query {
  shows(titleFilter: String): [Show]
}

type Show @key(fields: "id") {
  id: ID
  title: String
  releaseYear: Int
}
```

### Extending a federated Type

To extend a type you redefine the type in your own schema, using directive `@extends` to instruct that it's a type extension.
`@key` is required to indicate the field that the gateway will use to identify the original `Show` for a query.
In this case, the key is the `id` field.

```graphql
type Show @key(fields: "id") @extends {
  id: ID @external
  reviews: [Review]
}

type Review {
  starRating: Int
}
```
When redefining a type, only the id field, and the fields you're adding need to be listed.
Other fields, such as `title` for `Show` type are provided by the Shows DGS and do not need to be specified unless you are using it in the schema.
Federation makes sure the fields provided by all DGSs are combined into a single type for returning the results of a query.

!!!info
    Don't forget to use the @external directive if you define a field that doesn't belong to your DGS, but you need to reference it.

## Implementing a Federated Type
The very first step to get started is to generate Java types that represent the schema.
This is configured in `build.gradle` as described in the [manual](./generating-code-from-schema.md).
When running `./gradlew build` the Java types are generated into the `build/generated` folder, which are then automatically added to the classpath.

### Provide an Entity Fetcher
Let's go through an example of the following query sent to the gateway:
```graphql
query {
  shows {
    title
    reviews {
      starRating
    }
  }
}
```

The gateway first fetches the list of all the shows from the Shows DGS containing the title and id fields.
```graphql
query {
  shows {
    __typename
    id
    title
  }
}

```

Next, the gateway sends the following `_entities` query to the Reviews DGS using the list of `id`s from the first query:
```graphql
query($representations: [_Any!]!) {
  _entities(representations: $representations) {
    ... on Show {
      reviews {
        starRating
      }
    }
  }
}  
```

This query comes with the following variables:
```json
{
  "representations": [    
    {          
      "__typename": "Show",
      "id": 1
    },
    ,
    {
      "__typename": "Show",
      "id": 2
    },
    {
      "__typename": "Show",
      "id": 3
    },
    {
      "__typename": "Show",
      "id": 4
    },
    {
      "__typename": "Show",
      "id": 5
    }
  ]        
} 
```

The Reviews DGS needs to implement an `entity fetcher` to handle this query.
An entity fetcher is responsible for creating an instance of a `Show` based on the representation in the `_entities` query above.
The DGS framework does most of the heavy lifting, and all we have to do is provide the following:

[Full code](https://github.com/Netflix/dgs-federation-example/blob/master/reviews-dgs/src/main/java/com/example/demo/datafetchers/ReviewsDatafetcher.java)
```java
@DgsEntityFetcher(name = "Show")
public Show movie(Map<String, Object> values) {
        return new Show((String) values.get("id"), null);
}
```

!!!tip
    Remember that the Show Java type here is generated by codegen.
    It's generated from the schema, so it only has the fields our schema specifies.

!!!info
    Methods annotated using `@DgsEntityFetcher` are expected to return a concrete type (in this example: `Show`), `CompletionStage<T>` (e.g. `CompletableFuture<T>`), or Reactor `Mono<T>` instance.

    Instances of Reactor `Flux<T>` are not supported. When your scenario warrants returning a collection of concrete types, we suggest using [`Flux#collectList`](https://projectreactor.io/docs/core/release/api/reactor/core/publisher/Flux.html#collectList--).

### Providing Data with a Data Fetcher

Now the DGS knows how to create a Show instance when an `_entities` query is received, we can specify how to hydrate data for the reviews field.

[Full code](https://github.com/Netflix/dgs-federation-example/blob/master/reviews-dgs/src/main/java/com/example/demo/datafetchers/ReviewsDatafetcher.java#L37)
```java
@DgsData(parentType = "Show", field = "reviews")
public List<Review> reviews(DgsDataFetchingEnvironment dataFetchingEnvironment)  {
    Show show = dataFetchingEnvironment.getSource();
    return reviews.get(show.getId());
}
```

### Testing a Federated Query

You can always manually test federated queries by running the gateway and your DGS locally. 
You can also manually test a federated query against just your DGS, without the gateway, using the `_entities` query to replicate the call made to your DGS by the gateway.

For automated tests, the [QueryExecutor](./query-execution-testing.md) gives a way to run queries from unit tests, with very little startup overhead (in the order of 500ms).
We can capture (or manually write) the `_entities` query that the gateway sends to the DGS.
When running the query through the (locally running) gateway, the DGS will log the query that it receives.
Simply copy this query in a `QueryExecutor` test, and that verifies the DGS in isolation.

```java
@SpringBootTest(classes = {DgsAutoConfiguration.class, ReviewsDatafetcher.class})
class ReviewsDatafetcherTest {

    @Autowired
    DgsQueryExecutor dgsQueryExecutor;

    @Test
    void shows() {
        Map<String,Object> representation = new HashMap<>();
        representation.put("__typename", "Show");
        representation.put("id", "1");
        List<Map<String, Object>> representationsList = new ArrayList<>();
        representationsList.add(representation);

        Map<String, Object> variables = new HashMap<>();
        variables.put("representations", representationsList);
        List<Review> reviewsList = dgsQueryExecutor.executeAndExtractJsonPathAsObject(
                "query ($representations:[_Any!]!) {" +
                        "_entities(representations:$representations) {" +
                        "... on Show {" +
                        "   reviews {" +
                        "       starRating" +
                        "}}}}",
                "data['_entities'][0].reviews", variables, new TypeRef<>() {});

        assertThat(reviewsList)
                .isNotNull()
                .hasSize(3);
    }
}
```

To help build the federated `_entities` query, you can also use the `EntitiesGraphQLQuery` available in `graphql-dgs-client` package along with code generation. Here is an example of the same test that uses the builder API:

```java
@SpringBootTest(classes = {DgsAutoConfiguration.class, ReviewsDatafetcher.class})
class ReviewssDatafetcherTest {

    @Autowired
    DgsQueryExecutor dgsQueryExecutor;

    @Test
    void showsWithEntitiesQueryBuilder() {
        EntitiesGraphQLQuery entitiesQuery = new EntitiesGraphQLQuery.Builder().addRepresentationAsVariable(ShowRepresentation.newBuilder().id("1").build()).build();
        GraphQLQueryRequest request = new GraphQLQueryRequest(entitiesQuery, new EntitiesProjectionRoot<>().onShow().reviews().starRating());
        List<Review> reviewsList = dgsQueryExecutor.executeAndExtractJsonPathAsObject(
                request.serialize(),
                "data['_entities'][0].reviews", entitiesQuery.getVariables(), new TypeRef<>() {
                });
        assertThat(reviewsList).isNotNull();
        assertThat(reviewsList.size()).isEqualTo(3);
    }
}
```

For more details on the API and how to set it up for tests, please refer to our documentation [here](./advanced/federated-testing.md#Using-the-Entities-Query-Builder-API).

## Customizing the Default Federation Resolver

In the example above the GraphQL `Show` type name maps to the Java `Show` type.
There are also cases where the GraphQL and Java type names don't match, specially when working with existing code.
If any of your class names do not match your schema type names, you need to provide this class with a way to map between them.
To do this, return a map from the `typeMapping()` method in your own implementation of the `DefaultDgsFederationResolver`.
In the following example we map the GraphQL `Show` type to a `ShowId` Java type.

```java
@DgsComponent
public class FederationResolver extends DefaultDgsFederationResolver {
    private final Map<Class<?>, String> types = new HashMap<>();

    @PostConstruct
    public void init() {
        //The Show type is represented by the ShowId class.
        types.put(ShowId.class, "Show");
    }
    
    @Override
    public Map<Class<?>, String> typeMapping() {
        return types;
    }
}
```

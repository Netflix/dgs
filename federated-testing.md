[Federation](../../federation/what-is-federation.md) allows you to extend or reference existing types in a graph. 
Your DGS fulfills a part of the query based on the schema that is owned by your DGS, while the gateway is responsible for fetching data from other DGSs. 

!!!tip "There is more federation documentation available"
    * Look at the [Federation example app](../../federation/what-is-federation.md#testing-federated-entities), including testing. A tutorial style walkthrough of this example is available [here](../../federation/dgs-federation-example.md).
    
### Testing Federated Queries without the Gateway
You can test federated queries for your DGS in isolation by replicating the format of the query that the gateway would send to your DGS. 
This does not involve the gateway, and thus the parts of the query response that your DGS is not responsible for will not be hydrated. 
This technique is useful if you want to verify that your DGS is able to return the appropriate data, in response to a federated query. 

Let's look at an example of a schema that extends the `Movie` type that is already defined by another DGS.
```graphql
type Movie @key(fields: "movieId")  @extends {
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
Now you want to verify that your DGS is able to fulfill the Movie query by hydrating the `script` field based on the `movieId` field. 
Normally, the gateway would send an [_entities](https://www.apollographql.com/docs/apollo-server/federation/federation-spec/#resolve-requests-for-entities) query in the following format:
```java
 query ($representations: [_Any!]!) {
        _entities(representations: $representations) {
            ... on Movie {
                movieId
                script { title }
        }}}

```
The `representations` input is a variable map containing the `__typename` field set to `Movie` and `movieId` set to a value, e.g., `12345`.

You can now set up a [Query Executor](query-execution-testing.md) test by either manually constructing the query, or you can generate the federated query using the `Entities Query Builder API` available through [client code generation](../../clients/java-client.md#type-safe-query-api).


Here is an example of a test that uses a manually constructed `_entities` query for `Movie`:
```java
@Test
    void federatedMovieQuery() throws IOException {
         String query = "query ($representations: [_Any!]!) {" +
              "_entities(representations: $representations) {" +
                  "... on Movie {" +
                      "movieId " +
                      "script { title }" +
         "}}}";

        Map<String, Object> variables = new HashMap<>();
        Map<String,Object> representation = new HashMap<>();
        representation.put("__typename", "Movie");
        representation.put("movieId", 1);
        variables.put("representations", List.of(representation));

        DocumentContext context = queryExecutor.executeAndGetDocumentContext(query, variables);
        GraphQLResponse response = new GraphQLResponse(context.jsonString());
        Movie movie = response.extractValueAsObject("data._entities[0]", Movie.class);
        assertThat(movie.getScript().getTitle()).isEqualTo("Top Secret");
    }
```

#### Using the Entities Query Builder API
Alternatively, you can generate the federated query by using [EntitiesGraphQLQuery](../../clients/java-client.md#building-federated-queries) to build the graphql request in combination with the [code generation](../dgs-framework/generating-code-from-schema.md) plugin to generate the classes needed to use the request builder. 
This provides a convenient type-safe way to build your queries.

To set up code generation to generate the required classes to use for building your queries, follow the instructions [here](../../clients/java-client.md#type-safe-query-api).

You will also need to add `com.netflix.graphql.dgs:graphql-dgs-client:latest.release` dependency to build.gradle.  

Now we can write a test that uses `EntitiesGraphQLQuery` along with `GraphQLQueryRequest` and `EntitiesProjectionRoot` to build the query. Finally, you can also extract the response using `GraphQLResponse`. 

This set up is shown here:
```java
@Test
    void federatedMovieQueryAPI() throws IOException {
        // constructs the _entities query with variable $representations containing a 
        // movie representation that represents { __typename: "Movie"  movieId: 12345 }
        EntitiesGraphQLQuery entitiesQuery = new EntitiesGraphQLQuery.Builder()
                    .addRepresentationAsVariable(
                            MovieRepresentation.newBuilder().movieId(1122).build()
                    )
                    .build();
        // sets up the query and the field selection set using the EntitiesProjectionRoot
        GraphQLQueryRequest request = new GraphQLQueryRequest(
                    entitiesQuery,
                    new EntitiesProjectionRoot().onMovie().movieId().script().title());

        String query  = request.serialize();
        // pass in the constructed _entities query with the variable map containing representations
        DocumentContext context = queryExecutor.executeAndGetDocumentContext(query, entitiesQuery.getVariables());
        
        GraphQLResponse response = new GraphQLResponse(context.jsonString());
        Movie movie = response.extractValueAsObject("data._entities[0]", Movie.class);
        assertThat(movie.getScript().getTitle()).isEqualTo("Top Secret");
    }
```
Check out this [video](https://drive.google.com/file/d/1aOrvqAj7CQjRYd2YN4Yxq1ypKccJ_oxE/view?usp=sharing) for a demo on how to configure and write the above test.

<center><iframe src="https://drive.google.com/file/d/1aOrvqAj7CQjRYd2YN4Yxq1ypKccJ_oxE/preview" width="800" height="450"></iframe></center>


For a complete example of federation, please check out [these docs](../../federation/dgs-federation-example.md).

### Testing Federated Queries with the Gateway and Other DGSs
For a complete federated query test, you will need the gateway to talk to other DGSs as well for hydrating all the data for the response. 
You can do this by configuring your local gateway to talk to your DGS 
on the `local` host, while communicating with other deployed DGSs in the test environment. 
The gateway fetches your local DGS schema via introspection, and the remainder of the graph from DGSs deployed in test. 
Now you can run the same query against the gateway and verify the entire response.
The setup is described [here](../workflow/test.md).   

--8<-- "docs/reference_links"

[![Getting started](../../img/getting-started.png)](https://www.youtube.com/watch?v=d2dl4YsMEgk&feature=youtu.be)

In this tutorial you’ll create a [GraphQL] domain graph service by using the [DGS] framework.
You can run this service in a stand-alone fashion, and you can also plug it into the [Studio Edge Gateway].

The following is included in this tutorial:

* Adding the DGS framework dependency
* Creating a data fetcher
* Testing a data fetcher
* Extending the RuntimeWiring
* Adding type resolvers
* Adding [entity] fetchers and type resolvers for [federation]
* Overriding framework configuration and components - Creating a DataLoader

## Adding the [DGS] Framework Dependency

This tutorial assumes that you have created a [Spring Boot] application by using [Newt](http://manuals.netflix.net/view/newt/mkdocs/master/user-guides/apps/java/).
To add DGS functionality, add a single dependency to `build.gradle`:

```groovy
dependencies {
    compile 'com.netflix.graphql.dgs:graphql-dgs-starter:latest.release'
}
```

This starter pulls in the set of dependencies required to use the DGS framework, and sets up AutoConfiguration that bootstraps the framework.
You are now ready to design a schema and create the first data fetcher!

## Creating a Schema

Before you worry about providing data, you should first design a schema for the data.
You must add at least one schema file with the `.graphqls` extension in `src/main/resources/schema/`.
To get started, create a file `src/main/resources/schema/schema.graphqls` with the following contents.

```graphql
type Query {
   hello(name: String): String
}
```

This schema allows for a query like the following:

```graphql
query {
   hello(name:"Paul")
}
```

Such a query gives a result like the following:

```json
{
  "data": {
    "hello": "hello, Paul!"
  }
}
```

## IDE Schema File Compilation

If you are implementing a DGS, and therefore reference [federation directives](https://www.apollographql.com/docs/apollo-server/federation/federation-spec/#federation-schema-specification) in your schema SDL (such as `@extends`), you may see compile errors in your IDE. To fix this, add the federation directives to a directory whose schema files are not pushed to the schema registry. E.g., following the directions above, you can place your schema files (to push) in `src/main/resources/schema/`, but the federation dependencies in a file like, `src/main/resources/dontpush.graphqls` and push only schema files found in the `schema/` subdirectory. The schema file containing the shared federation directives and types will look something like this:

```graphql
# WARNING! DO NOT PUSH THIS SCHEMA
# It's just to reduce IntelliJ compile errors

scalar _Any
scalar _FieldSet
scalar DateTime

# a union of all types that use the @key directive
union _Entity

type _Service {
  sdl: String
}

type Query @extends {
  _entities(representations: [_Any!]!): [_Entity]!
  _service: _Service!
}

directive @external on FIELD_DEFINITION
directive @requires(fields: _FieldSet!) on FIELD_DEFINITION
directive @provides(fields: _FieldSet!) on FIELD_DEFINITION
directive @key(fields: _FieldSet!) on OBJECT | INTERFACE

# this is an optional directive discussed below
directive @extends on OBJECT | INTERFACE
```

Now it's time to write some code!

## Creating a Data Fetcher

A data fetcher is the method that returns the data for a specific key in a [GraphQL] query.
The [DGS] framework has custom annotations that make it trivial to register data fetchers.
Create a new class with the following contents:

```java
import com.netflix.graphql.dgs.DgsComponent;
import com.netflix.graphql.dgs.DgsData;
import graphql.schema.DataFetchingEnvironment;

@DgsComponent
public class HelloDataFetcher {
    @DgsData(parentType = "Query", field = "hello")
    public String hello(DataFetchingEnvironment dfe) {

        String name = dfe.getArgument("name");

        return "hello, " + name + "!";
    }
}
```

The `@DgsComponent` annotation marks this class as a class that the DGS framework should be interested in.
The actual capabilities of the class are defined by annotations on the method level, in this case `@DgsData`.
The `@DgsData` annotation takes a `parentType` and `key` as arguments. 
The `parentType` is the object type, as defined in the GraphQL schema, on which a field is defined.
The key is the name of the field.
In the example schema, the `hello` field is defined on the `Query` object type.
This means the `parentType` is `Query` and the field is `hello` for the `@DsgData` annotation.

Write a method that you have annotated with `@DgsData` so that it receives an argument of type `DataFetchingEnvironment`, which is a type coming from the `graphql-java` library.
This type gives access to arguments, the parent type, data loaders, etc.

That’s it! 
You’re ready to accept GraphQL queries. 
The starter includes GraphiQL, which is available at [https://localhost:8443/graphiql](https://localhost:8443/graphiql).

You can enter the sample query from above and hit the play button to run your first DGS query:

```graphql
query {
   hello(name:"Paul")
}
```

!!!note "Fun Fact"
    The `graphiql` and `graphql` endpoints already use [Meechum] out of the box.

## Optimizing the Development Workflow

[Spring Boot] with all its Netflix integrations is great for developers, except for the relatively slow application startups (1+ minute for even the simplest app).
The slow startups are caused by the many integrations that are provided out-of-the-box to Netflix infrastructure.
These integrations make using our infrastructure easy, but come at a cost when starting the application.

Especially in the early stages of developing a [GraphQL] service, it’s often helpful for you to make small experimental changes to both the schema and the datafetchers.
Unfortunately, that workflow typically would require that you restart after each change, which obviously really slows down the development workflow.
To some extent you can avoid this by using the framework’s [testing capabilities](../testing/testing.md), but that’s not always the easiest option.

The [DGS] framework is optimized to prevent restarts during development.
To get the most benefits (and pretty much eliminate restarts), install the commercial plugin [JRebel](https://www.jrebel.com/products/jrebel). 
Although JRebel is commercial, and not cheap, it can drastically improve developer experience.

!!!tip "How to get JRebel"
    Reach out to [#engineering-help] to see if any corporate JRebel licenses are available.
    Last time we checked, no such licenses were available through Netflix, and you were encouraged to purchase a personal license and [expense it](https://docs.google.com/presentation/d/1L3XDckaGaDMGE3l6GklnoIPVCEmYOA_7ogW1JJ_fVhI/edit#slide=id.g7453464844_1_43).
    Also, contact [Jose Ferrel](mailto:jferrel@netflix.com) in Technology Deployment to let him know that there is interest for Netflix-wide JRebel licensing.

JRebel hot-loads code changes and integrates with Spring Boot to dynamically reload Spring components whenever you make changes to them.
The DGS framework picks up schema changes dynamically, and rewires DGS components such as data loaders and data fetchers.

!!!tip "Disabling Auto-Rewiring"
    If you want to disable this automatic rewiring, add the following section to your `application.yml`:

        dgs:
          reload: false

    You could instead disable automatic rewiring for tests only by setting this property in the `properties` block of your `@SpringBootTest` declaration in the file where you import `DgsAutoConfiguration`:

        @SpringBootTest(classes= {some.class, another.class},
                        properties="dgs.reload=false")

    See [Writing Tests](../testing/testing.md).

Without JRebel, some of the functionality is still available.
Schema changes are still dynamic, and basic code changes such changing the implementation of a method can be hot swapped by IntelliJ.
However, if you make any structural changes to the code, or add new components, this will still require that you restart. 

[![Getting started](../../img/jrebel.png)](https://www.youtube.com/watch?v=exVIlF5q3ys&feature=youtu.be)

--8<-- "docs/reference_links"


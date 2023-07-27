# About

In addition to the [Java and Kotlin code-gen](./java-client.md), we also have an experimental Kotlin API that generates more idiomatic Kotlin classes.
Instead of generating Java code that can be used in Kotlin, it generates native Kotlin code that leans into techniques that only Kotlin supports.
This is split primarily into two parts: the data classes used to serialize responses (both in the server and in the client), and the client query projections

## Data Classes

Kotlin introduces strict nullability as a language feature.
This is at odds with GraphQL in that it is often the case that response objects are partially defined.
Because some fields may be absent simply because the caller didn't request them, all fields must support being absent.
To solve for this, we must split these absent fields into two categories: those that are nullable fields that the user requested, where GQL defines the schema as nullable & the Kotlin type is nullable, and those that the user did not request.
For the latter, if they are consumed anywhere, we should throw an exception to alert the user that they are trying to use a field that was not requested.
This split is advantageous because it can help us to catch errors earlier in the process: if a field is usually null, a client may not notice that it wasn't requested in the query, or the server may not notice that it was never being populated in responses.

The generated classes in this mode wrap each field in a `Supplier<T>`, or in Kotlin, `() -> T`.
This is very similar to lazy values, but with some differences.
What this allows us to do is defer the evaluation of a field until it is accessed, either on the server for serialization, or on the client for consumption.
Luckily, the Kotlin closure syntax allows us a compact way to express these, simply by wrapping them in curly braces:

```kotlin
val series = Series(
    title = { "Stranger Things" },
    actors = { listOf("Millie Bobby Brown", "Finn Wolfhard", "Winona Ryder", "David Harbour") },
)
```

Alternatively, we also generate builder methods where you can construct these objects as such:

```kotlin
val series = Series.Builder()
    .withTitle("Stranger Things")
    .withReleaseDate(2016)
    .withEndDate(2024)
```

Note that in each of these examples, we're only populating partial objects, which is frequently the case in GQL.
If the user were to access either the release dates in the first example, or the list of actors in the second, an exception would be thrown indicating that those fields are not populated.

We can also specify explicit null response values for when we want to return an explicit null value for a field that was requested:


```kotlin
val series = Series(
    title = { "Black Mirror" },
    releaseDate = { 2011 },
    endDate = { null },
)
```

In this example, `endDate` would be a nullable Kotlin field, whereas `title` would be non-nullable.
Also note that the supplier closure is not exposed when accessing the fields.
These are all properties that fetch the value when accessed (or throw an exception if it was not populated)

```kotlin
val title: String = series.title
val releaseDate: Int = series.releaseDate
val endDate: Int? = series.endDate
```

## Query Projections

Kotlin supports [function literals with a receiver](https://kotlinlang.org/docs/lambdas.html#function-literals-with-receiver) and this allows us to mimic the GQL query syntax, directly in the language.
An advantage of writing queries directly in the language is that when the schema changes, any incompatibilities will show up as compile time errors, and the IDE can guide users to craft queries.
Additionally, nested projections are nested in the query, just as they appear in a GQL query.
For example:

```kotlin
val query: String = DgsClient.buildQuery {
    series(title = "Stranger Things") {
        actors {        // slightly different schema for example
            name 
            age
        }
        releaseDate
        endDate
    }
}
```

In the end, the only difference between a GQL query and the syntax above is that in GQL, the projection arguments are delineated with a `:` whereas in Kotlin we use `=`.

## Usage

To generate these Kotlin classes, use the following properties when configuring the code-gen plugin:

```groovy
    language = 'kotlin'
    generateClient = true
    generateKotlinNullableClasses = true
    generateKotlinClosureProjections = true
```

In order, they do the following:

* Use kotlin instead of java
* Enable client generation at all
* Generate the data classes described above
* Generate the query projections described above

As part of your generated code, you'll have a `DgsClient` class, which will serve as the entrypoint for queries/mutations/subscriptions

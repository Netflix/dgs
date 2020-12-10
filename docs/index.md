
## GraphQL for Spring Boot

The DGS framework makes implementing a GraphQL server with Spring Boot easy.
The framework includes features such as: 

* First class support for both Java and Kotlin
* Annotation based Spring Boot programming model
* Test framework for writing query tests as unit tests
* Gradle Code Generation plugin to create types from schema
* Easy integration with GraphQL Federation
* Integration with Spring Security
* GraphQL subscriptions (WebSockets and SSE)
* File uploads
* Error handling
* Many extension points

The framework started in 2019 when Netflix started developing many GraphQL services.
At the end of 2020 Netflix decided to open source the framework and build a community around it.
 
## Getting started

Jump right in with the getting started [guide](getting-started)!

## Q & A

### Why start with release version 3.x?

Netflix developed and used the framework over the course of almost two years before open sourcing, which involved many releases.
After open sourcing the project, we are now using the OSS project internally as well.
We did have to wipe out the git history, but continued the versioning we were already using.

### Is it production ready?

Yes! Netflix has been using the framework for over a year and a half in different parts of our organisation, including at large scale, before it was open sourced.
We've had many releases adding new features, fixing bugs etc., and it has become a very stable platform.

### Why not just use graphql-java?

The DGS framework is built on top of `graphql-java`.
Graphql-java is, and should be, lower level building blocks to handle query execution and such.
The DGS framework makes all this available with a convenient Spring Boot programming model.

### The framework has a lot of Kotlin code, can I use it with Java?

The DGS framework is primarily designed to be used with Java.
Although it's primarily written in Kotlin, most consumers of the framework are Java.
Of course, if you are using Kotlin, that works great too.

### Does Netflix run on a fork of the framework?

No, Netflix is using the same OSS components! 
We do have some extra modules plugged in for distributed tracing, logging, metrics etc, and we have documentation that shows how to implement similar integrations for your own infrastructure.


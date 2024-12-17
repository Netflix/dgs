### DGS Framework 10.0.0 released! (Dec 17, 2024)
DGS 10.0.0 removes all the legacy code in favor of our integration with Spring for GraphQL.
In March 2024 we released deep integration with Spring for GraphQL after working closely with the Spring team.
This integration makes it possible to mix and match features from DGS and Spring for GraphQL, and leverages the web transports provided by Spring for GraphQL.
With the March released we declared the "old" DGS starter, and the implementation code legacy, with the plan to remove this code end of 2024.
The community has adopted the DGS/Spring for GraphQL integration really well, in most cases without any required code changes.
At Netflix we migrated all our services to use the new integration, again mostly without any code changes.
Performance is critical for our services, and after all the performance optimization that went into the March release and some patch releases after, we see the same performance with the Spring for GraphQL integration as what we had previously.

DGS 10.0.0 finalizes the integration work by removing all the legacy modules and code.
This greatly reduces the footprint of the codebase, which will speed up feature development into the future!

Although the list of changes is large, you probably won't notice the difference for your applications!
Just make sure to use the (new) `netflix.graphql.dgs:dgs-starter` AKA `netflix.graphql.dgs:graphql-dgs-spring-graphql-starter` starter!

#### Detailed list of changes

New modules:

* `netflix.graphql.dgs:dgs-starter` as a nicer/shorter name for `netflix.graphql.dgs:graphql-dgs-spring-graphql-starter`.

Deleted modules:

* `graphql-dgs-spring-boot-oss-autoconfigure` (replaced by Spring for GraphQL)
* `graphql-dgs-spring-webmvc` (replaced by Spring for GraphQL)
* `graphql-dgs-spring-webmvc-autoconfigure` (replaced by Spring for GraphQL)
* `graphql-dgs-spring-boot-starter` (replaced by `netflix.graphql.dgs:dgs-starter`)
* `graphql-dgs-example-java` (legacy example, no longer relevant)
* `graphql-dgs-example-java-webflux` (legacy example, no longer relevant)
* `graphql-dgs-mocking` (old feature that wasn't used much)
* `graphql-dgs-subscriptions-websockets` (replaced by Spring for GraphQL)
* `graphql-dgs-subscriptions-websockets-autoconfigure` (replaced by Spring for GraphQL)
* `graphql-dgs-subscriptions-graphql-sse` (replaced by Spring for GraphQL)
* `graphql-dgs-subscriptions-graphql-sse-autoconfigure` (replaced by Spring for GraphQL)
* `graphql-dgs-subscriptions-sse` (replaced by Spring for GraphQL)
* `graphql-dgs-subscriptions-sse-autoconfigure` (replaced by Spring for GraphQL)
* `graphql-dgs-spring-webflux-autoconfigure` (replaced by Spring for GraphQL)
* `graphql-dgs-webflux-starter` (replaced by `netflix.graphql.dgs:dgs-starter`)

Deleted classes:

* `DgsAutoConfiguration`: Autoconfiguration classes have moved. This may break tests that are using @SpringBootTest(classes = {DgsAutoConfiguration.class, ...}, and should use @EnableDgsTest instead.
* `DefaultGraphQLClient`: This is a long deprecated class that has been replaced by [CustomGraphQLClient, CustomReactiveGraphQLClient and WebClientGraphQLClient.
* `DefaultDgsReactiveQueryExecutor`: There should be no user impact because its interface should be used instead.
* `DefaultDgsQueryExecutor`: There should be no user impact because its interface should be used instead.

Other changes:

* We're now using the K2 compiler and Kotlin 2.1.
* Subscriptions over SSE in Spring GraphQL are using the newer, more official GraphQL over SSE RFC spec. The old spec is no longer supported by DGS.
* If you are using SSESubscriptionGraphQLClient in tests to test your DGS server, switch to GraphqlSSESubscriptionGraphQLClient, which has the same interface, but uses the new protocol.
* SSESubscriptionGraphQLClient can still be used to call into other services using the old protocol, but this client is now deprecated for removal in the future.
* Note that Spring GraphQL serves subscriptions on the /graphql endpoint, not on the /subscriptions endpoint like DGS used to do.

### DGS Framework 8.5.0 with Spring GraphQL released! (March 29,2024)
The DGS and Spring-GraphQL teams are super excited to introduce deep integration between the DGS framework and Spring-GraphQL. 
This will bring the community together, and we can continue building the best possible GraphQL framework for Spring Boot in the future.
We have been actively working on this integration over the past several months and are preparing for a release in the coming weeks.

Check out our [release notes](https://github.com/Netflix/dgs-framework/releases/tag/v8.5.0) for all the details! Additional details are available in [here](./spring-graphql-integration.md)

### DGS Framework 8.0.0
This release updates the graphql-java version to 21.2. 
The main breaking change affects the usage of the already deprecated DefaultExceptionHandler::onException method. 
If you have defined your own custom exception handlers, you will need to switch to using handleException instead of onException.

### DGS Framework 7.0.0 (May 15, 2023)
The latest 7.0.0 release updates the version of graphql-java from graphql-java-19.5 -> graphql-java [20.2](https://github.com/graphql-java/graphql-java/releases/tag/v20.2). Graphql-java-20.0 introduces breaking changes. Refer to the notes [here](https://github.com/graphql-java/graphql-java/releases/tag/v20.0).

Other dependencies updated include :

- graphql-java-extended-scalars: 19.1 -> [20.2](https://github.com/graphql-java/graphql-java-extended-scalars/releases/tag/20.2)
- graphql-java-extended-validation: 19.1 -> [20.0](https://github.com/graphql-java/graphql-java-extended-validation/releases/tag/20.0)
- federation-graphql-java-support: 2.1.0 -> [3.0.0](https://github.com/apollographql/federation-jvm/releases/tag/v3.0.0)

### DGS Framework 6.0.0 now on Spring Boot 3.0.0! (January 17, 2023)
The 6.0.0 release now supports Spring Boot 3.0.0. 
This is a breaking change and requires the application to be using Spring Boot 3.0.0 and JDK 17.
We will continue to maintain a separate 5.x.x release train for supporting Spring Boot 2.7 for the near future for any minor bug fixes and improvements.

The following versions are updated:
* Spring Boot 3.0.0
* Spring Framework 6.0.3
* Spring Security 6.0.1
* Spring Cloud 2022.0.0
* JDK target 17

#### Other Breaking Changes
##### Use GraphQLContext instead of DgsContext for dataloaders
Previously, the DGS framework passed DgsContext to dataloaders as context. 
CustomContext is contained in DgsContext, and is generally retrieved with a static helper.
```
MyContext context = DgsContext.getCustomContext(environment);
```
The helper DgsContext::getCustomContext is able to pull MyContext from GraphQLContext, so this is non-breaking for users that employ the recommended helper method.
This is potentially a breaking change for any user code that coerces dataloader context to DgsContext manually.
Updating to using the recommended `getCustomContext` should fix any resulting issues.
```
MyContext context = (DgsContext)environment.context;
```

### Upcoming Release of the DGS Framework for Spring Boot 3.0 (January 10, 2023)
We plan to release a new version 6.x of the DGS Framework supporting Spring Boot 3.0 by end of January 2023. 
There are no known additional changes required to use the new version of the DGs framework.
We will continue to maintain a separate release train for the DGS framework (5.x.x) on Spring Boot 2.7 till the end of 2023.
Only patches and minor features will be available on the Spring Boot 2.7 compatible releases. 



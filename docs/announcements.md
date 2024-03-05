### Coming Soon!! DGS Framework with Spring GraphQL 
The DGS and Spring-GraphQL teams are super excited to introduce deep integration between the DGS framework and Spring-GraphQL. 
This will bring the community together, and we can continue building the best possible GraphQL framework for Spring Boot in the future.
We have been actively working on this integration over the past several months and are preparing for a release in the coming weeks.


### DGS Framework 8.0.0
This release updates the graphql-java version to 21.2. 
The main breaking change affects the usage of the already deprecated DefaultExceptionHandler::onException method. 
If you have defined your own custom exception handlers, you will need to switch to using handleException instead of onException.

### DGS Framework 7.0.0 (May 15, 2023)
The latest 7.0.0 release updates the version of graphql-java from graphql-java-19.5 -> graphql-java [20.2](https://github.com/graphql-java/graphql-java/releases/tag/v20.2). Graphql-java-20.0 introduces breaking changes. Refer to the notes [here](https://github.com/graphql-java/graphql-java/releases/tag/v20.0).
Timnp247!

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



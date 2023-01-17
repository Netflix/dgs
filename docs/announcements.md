### DGS Framework 6.0.0 now on Spring Boot 3.0.0! (January 16, 2023)
The latest 6.0.0 release now supports Spring Boot 3.0.0. 
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

### Upcoming Release of the DGS Framework for Spring Boot 3.0 (January 10, 2024)
We plan to release a new version 6.x of the DGS Framework supporting Spring Boot 3.0 by end of January 2023. 
There are no known additional changes required to use the new version of the DGs framework.
We will continue to maintain a separate release train for the DGS framework (5.x.x) on Spring Boot 2.7 till the end of 2023.
Only patches and minor features will be available on the Spring Boot 2.7 compatible releases. 



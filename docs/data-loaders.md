Data loaders solve the [N+1 problem](https://stackoverflow.com/q/97197/8237967) while loading data.

## The N+1 Problem Explained
Say you query for a list of movies, and each movie includes some data about the director of the movie.
Also assume that the Movie and Director entities are owned by two different services.
In a naïve implementation, to load 50 movies, you would have to call the Director service 50 times: once for each movie.
This totals 51 queries: one query to get the list of movies, and 50 queries to get the director data for each movie.
This obviously wouldn’t perform very well.

It would be much more efficient to create a list of directors to load, and load all of them at once in a single call.
This first of all _must be supported by the Director service_, because that service needs to provide a way to load a list of Directors.
The data fetchers in the Movie service need to be smart as well, to take care of batching the requests to the Directors service.

This is where data loaders come in.

## What If My Service Doesn’t Support Loading in Batches?

What if (in this example) `DirectorServiceClient` doesn’t provide a method to load a list of directors?
What if it only provides a method to load a single director by ID?
The same problem applies to REST services as well: what if there’s no endpoint to load multiple directors?
Similarly, to load from a database directly, you must write a query to load multiple directors.
If such methods are unavailable, the providing service needs to fix this!

## Implementing a Data Loader

The easiest way for you to register a data loader is for you to create a class that implements the `org.dataloader.BatchLoader` or `org.dataloader.MappedBatchLoader` interface.
This interface is parameterized; it requires a type for the key and result of the `BatchLoader`.
For example, if the identifiers for a Director are of type `String`, you could have a `org.dataloader.BatchLoader<String, Director>`.
You must annotate the class with `@DgsDataLoader` so that the framework will register the data loader it represents.

In order to implement the `BatchLoader` interface you must implement a `CompletionStage<List<V>> load(List<K> keys)` method.

The following example is a data loader that loads data from an imaginary Director service:

```java
package com.netflix.graphql.dgs.example.dataLoader;

import com.netflix.graphql.dgs.DgsDataLoader;
import org.dataloader.BatchLoader;

import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;
import java.util.stream.Collectors;

@DgsDataLoader(name = "directors")
public class DirectorsDataLoader implements BatchLoader<String, Director> {

    @Autowired
    DirectorServiceClient directorServiceClient;

    @Override
    public CompletionStage<List<Director>> load(List<String> keys) {
        return CompletableFuture.supplyAsync(() -> directorServiceClient.loadDirectors(keys));
    }
}
```

The data loader is responsible for loading data for a given list of keys.
In this example, it just passes on the list of keys to the backend that owns `Director` (this could for example be a [gRPC] service).
However, you might also write such a service so that it loads data from a database.
Although this example registers a data loader, nobody will use that data loader until you implement a data fetcher that uses it.


## Implementing a Data Loader With Try
If you want to handle exceptions during fetching of partial results, you can return a list of `Try` objects from the loader. 
The query result will contain partial results for the successful calls and  an error for the exception case.

```java
package com.netflix.graphql.dgs.example.dataLoader;

import com.netflix.graphql.dgs.DgsDataLoader;
import org.dataloader.BatchLoader;
import org.dataloader.Try;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;
import java.util.stream.Collectors;

@DgsDataLoader(name = "directors")
public class DirectorsDataLoader implements BatchLoader<String, Try<Director>> {

    @Autowired
    private DirectorServiceClient directorServiceClient;

    @Override
    public CompletionStage<List<Try<Director>>> load(List<String> keys) {
        return CompletableFuture.supplyAsync(() -> keys.stream()
                .map(key -> Try.tryCall(() -> directorServiceClient.loadDirectors(keys)))
                .collect(Collectors.toList()));
    }

}
```

## Provide as Lambda

Because `BatchLoader` is a functional interface (an interface with only a single method), you can also provide it as a lambda expression.
Technically this is exactly the same as providing a class; it’s really just another way of writing it:

```java
@DgsComponent
public class ExampleBatchLoaderFromField {
    @DgsDataLoader(name = "directors")
    public BatchLoader<String, Director> directorBatchLoader = keys -> CompletableFuture.supplyAsync(() -> directorServiceClient.loadDirectors(keys));
}
```

## MappedBatchLoader

The `BatchLoader` interface creates a `List` of values for a `List` of keys.
You can also use the `MappedBatchLoader` which creates a `Map` of key/values for a `Set` of values.
The latter is a better choice if you do not expect all keys to have a value.
You register a `MappedBatchLoader` in the same way as you register a `BatchLoader`:

```java
@DgsDataLoader(name = "directors")
public class DirectorsDataLoader implements MappedBatchLoader<String, Director> {

    @Autowired
    DirectorServiceClient directorServiceClient;

    @Override
    public CompletionStage<Map<String, Director>> load(Set<String> keys) {
        return CompletableFuture.supplyAsync(() -> directorServiceClient.loadDirectors(keys));
    }
}
```

## Using a Data Loader

The following is an example of a data fetcher that uses a data loader:

```java
@DgsComponent
public class DirectorDataFetcher {

    @DgsData(parentType = "Movie", field = "director")
    public CompletableFuture<Director> director(DataFetchingEnvironment dfe) {

        DataLoader<String, Director> dataLoader = dfe.getDataLoader("directors");
        String id = dfe.getArgument("directorId");

        return dataLoader.load(id);
    }
}
```

The code above is mostly just a regular data fetcher.
However, instead of actually loading the data from another service or database, it uses the data loader to do so.
You can retrieve a data loader from the `DataFetchingEnvironment` with its `getDataLoader()` method.
This requires  you to pass the name of the data loader as a string.
The other change to the data fetcher is that it returns a `CompletableFuture` instead of the actual type you’re loading.
This enables the framework to do work asynchronously, and is a requirement for batching<!-- http://go/pv -->.

### Using the DgsDataFetchingEnvironment
You can also get the data loader in a type-safe way by using our custom `DgsDataFetchingEnvironment`, which is an enhanced version of `DataFetchingEnvironment` in `graphql-java`, and provides `getDataLoader()` using the classname.

```java
@DgsComponent
public class DirectorDataFetcher {

    @DgsData(parentType = "Movie", field = "director")
    public CompletableFuture<Director> director(DgsDataFetchingEnvironment dfe) {

        DataLoader<String, Director> dataLoader = dfe.getDataLoader(DirectorsDataLoader.class);
        String id = dfe.getArgument("directorId");

        return dataLoader.load(id);
    }
}
```


The same works if you have `@DgsDataLoader` defined as a lambda instead of on a class as shown [here](data-loaders.md#provide-as-lambda).
If you have multiple `@DgsDataLoader` lambdas defined as fields in the same class, you won't be able to use this feature.
It is recommended that you use `getDataLoader()` with the loader name passed as a string in such cases.

Note that there is no logic present about how batching works exactly; this is all handled by the framework!
The framework will recognize that many directors need to be loaded when many movies are loaded, batch up all the calls to the data loader, and call the data loader with a list of IDs instead of a single ID.
The data loader implemented above already knows how to handle a list of IDs, and that way it avoids the N+1 problem.

## Using Spring Features such as SecurityContextHolder inside a CompletableFuture

All the `*async*` methods on `CompletableFuture` allow you to provide an `Executor`.
If provided, that stage of the `CompletableFuture` will run on a Thread represented by that `Executor`.
If no `Executor` is provided, the stage runs on a Thread from the fork/join pool.

In Spring WebMVC it's common to store request information such as SSO data on `ThreadLocal`, which doesn't automatically become available if you run on a different thread, in this case a thread from the `Executor`.
Spring Security uses `ThreadLocal` for example to store its `SecurityContext`.

While creating and extending an `Executor` with the correct context propagation goes beyond the scope of this documentation, a good place to start is the `DelegatingSecurityContextExecutor` from Spring Security.
A relevant howto guide is available [here](https://www.baeldung.com/spring-security-async-principal-propagation). 


## Scheduled Data Loaders with Dispatch Predicates
The framework now supports setting up a [Dispatch Predicate](https://github.com/graphql-java/java-dataloader#scheduled-dispatching) on a per data loader basis. 
This allows you to configure when the batch is dispatched based on queue depth or time. 
Note that the predicate will be applied for the data loader that you set the predicate up for and not across all data loaders.
Here is how you can set up a `DispatchPredicate` for an example data loader:
```java
@DgsDataLoader(name = "messagesWithScheduledDispatch")
public class MessageDataLoaderWithDispatchPredicate implements BatchLoader<String, String> {
    @DgsDispatchPredicate
    DispatchPredicate pred = DispatchPredicate.dispatchIfLongerThan(Duration.ofSeconds(2));

    @Override
    public CompletionStage<List<String>> load(List<String> keys) {
        return CompletableFuture.supplyAsync(() -> keys.stream().map(key -> "hello, " + key + "!").collect(Collectors.toList()));
    }
}

```

In addition to defining the `load` method for the data loader class, you can specify a DispatchPredicate annotated with `@DgsDispatchPredicate` to apply that for the specific data loader.

### Chaining Data Loaders
Often times, you may want to chain data loaders as shown in the following example:
```java
 @DgsData(parentType = "Query", field = "messageFromBatchLoader")
    public CompletableFuture<String> getMessage(DataFetchingEnvironment env) {
        DataLoader<String, String> dataLoader = env.getDataLoader("messages");
        DataLoader<String, String> dataLoaderB = env.getDataLoader("greetings");
        return dataLoader.load("a").thenCompose(key -> {
            CompletableFuture<String> loadA = dataLoaderB.load(key);
            return loadA;
        });
    }

```

The above implementation will hang indefinitely in the call to the second data loader in the chain.
The `java-dataloader` library already handles dispatching of data loader calls at each level of the query. 
However, when there is yet another load call to the same or different dataloader, who would call dispatch on this data loader?
Since these return Completable Futures, it is not easy to determine when the dispatch should be triggered.
To handle this, we need to explicitly call dispatch on the second data loader (shown below) , since there is nothing else to trigger the dispatch when load is invoked on `dataloaderB`.
```java
 @DgsData(parentType = "Query", field = "messageFromBatchLoader")
    public CompletableFuture<String> getMessage(DataFetchingEnvironment env) {
        DataLoader<String, String> dataLoader = env.getDataLoader("messages");
        DataLoader<String, String> dataLoaderB = env.getDataLoader("greetings");
        return dataLoader.load("a").thenCompose(key -> {
            CompletableFuture<String> loadA = dataLoaderB.load(key);
            // Manually call dispatch
            dataLoaderB.dispatch();
            return loadA;
        });
    }

```
This is expected according to the documented behavior [here](https://github.com/graphql-java/java-dataloader#chaining-dataloader-calls).
However, this can result in suboptimal batching for `dataloaderB`, with a bacth size of 1.

The `v8.1.0` release introduces a new feature to [enable ticker mode](https://github.com/graphql-java/java-dataloader#scheduleddataloaderregistry-ticker-mode) available in the `java-dataloader` library
This allows you to schedule the dispatch checks instead of manually calling dispatch in your data loaders.
By default, the checks will occur every 10ms but can be configured via `dgs.graphql.dataloader.scheduleDuration`.
To enable ticker mode in the DGS framework, you can set `dgs.graphql.dataloader.ticker-mode-enabled` to true.
In addition, you can also specify [dispatch predicates](## Scheduled Data Loaders with Dispatch Predicates) per dataloader vi a`@DgsDispatchPredicate`to better control the batching.

With ticker mode enabled, you can eliminate calls to manually dispatch and rely on the scheduler to periodically check and dispatch any batches as needed.
This should result in better batching behavior overall.
Thus the following implementation that would hang earlier will now work as expected without the additional call to dispatch:
```java
 @DgsData(parentType = "Query", field = "messageFromBatchLoader")
    public CompletableFuture<String> getMessage(DataFetchingEnvironment env) {
        DataLoader<String, String> dataLoader = env.getDataLoader("messages");
        DataLoader<String, String> dataLoaderB = env.getDataLoader("greetings");
        return dataLoader.load("a").thenCompose(key -> {
            CompletableFuture<String> loadA = dataLoaderB.load(key);
            return loadA;
        });
    }
```


## Thread Pool Optimization

Using `supplyAsync()` without a second argument will cause the main work of a data loader to run on a [common thread pool](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ForkJoinPool.html#commonPool--) 
shared with most other async operations in your application. If that data loader is responsible for calling a slow service and/or subject to heavy load, the common thread pool could become fully saturated.
In the worst case, this could result in application "freezes" as each data loader in the application awaits a free thread from the fixed-size common pool. 

To account for this, IO-bound data loaders should instead maintain their own dedicated thread pool rather than use the common pool.
When choosing a thread pool, it's recommended to review the options under the [Executors Javadoc](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Executors.html),
but a safe default for IO bound workloads is usually `Executors.newCachedThreadPool()`. As opposed to the fixed-size common thread pool, `Executors.newCachedThreadPool()` will 
create new threads on-demand if all previously-created threads are saturated, but still prefers thread re-use when possible.

```java
@Configuration
public class SlowDataLoaderConfiguration {
    @Bean(name = "SlowDataLoaderThreadPool")
    Executor slowDataLoaderExecutor() {
        return Executors.newCachedThreadPool();
    }
}
```

Individual Bean names combined with `@Qualifier` annotations will result in the proper executor being autowired to the corresponding data loader.

```java
@DgsDataLoader(name = "slow")
public class SlowDataLoader implements MappedBatchLoader<String, Snail> {

    @Autowired
    @Qualifier("SlowDataLoaderThreadPool")
    Executor dedicatedExecutor;
    
    @Autowired
    DirectorServiceClient directorServiceClient;

    @Override
    public CompletionStage<Map<String, Snail>> load(Set<String> keys) {
        // This slow operation will now run on a dedicated thread pool instead of the common pool
        return CompletableFuture.supplyAsync(() -> directorServiceClient.loadSlowData(keys), dedicatedExecutor);
    }
}
```

Note that a custom executor will not carry Spring Security context automatically. 
Further documentation on passing Spring Security context between threads can be found in the [Spring Security Concurrency docs](https://docs.spring.io/spring-security/reference/features/integrations/concurrency.html).

## Caching

Batching is the most important aspect of preventing N+1 problems.
Data loaders also support caching, however.
If the same key is loaded<!-- http://go/pv --> multiple times, it will only be loaded<!-- http://go/pv --> once.
For example, if a list of movies is loaded<!-- http://go/pv -->, and some movies are directed by the same director, the director data will only be retrieved<!-- http://go/pv --> once.

!!!info "Caching is Disabled by Default in DGS 1"
    Version 1 of the DGS framework disables caching by default, but you can switch it on in the `@DgsDataLoader` annotation:

```java
@DgsDataLoader(name = "directors", caching=true)
class DirectorsBatchLoader implements BatchLoader<String, Director> {}
```

You do not need to make this change in version 2 of the DGS framework, because that version enables caching by default.

## Batch Size

Sometimes it’s possible to load<!-- http://go/pv --> multiple items at once, but to a certain limit.
When loading<!-- http://go/pv --> from a database for example, an `IN` query could be used<!-- http://go/pv http://go/use -->, but maybe with the limitation of a maximum number of IDs to provide.
The `@DgsDataLoader` has a `maxBatchSize` annotation that you can use to configure this behavior.
By default it<!-- "it" is ambiguous here --> does not specify a maximum batch size.

## Data Loader Scope

Data loaders are wired up<!-- http://go/pv --> to only span a single request.
This is what most use cases require.
Spanning<!-- http://go/pv --> multiple requests can introduce difficult-to-debug issues.

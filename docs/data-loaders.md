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

When you write async data fetchers, the code will run on worker threads.
Spring internally stores some context, for example to make the SecurityContextHolder work, on the thread context however.
This context wouldn’t be available inside code running on a different thread, which makes fetching the Principal associated
with the request not work.

Spring Boot has a solution for this: it manages a thread pool that *does* have this context carry over.
You can inject this solution in the following way:

```java
@Autowired
@DefaultExecutor
private Executor executor;
```

You must pass in the executor as the second argument of the `supplyAsync()` method which<!-- which == the executor? the method? the argument? --> is typically used<!-- http://go/pv --> to make data fetchers asynchronous.

```java
@DgsData(parentType = "Query", field = "list_things")
public CompletableFuture<List<Thing>> resolve(DataFetchingEnvironment environment) {
 return CompletableFuture.supplyAsync(() -> {
    return myService.getThings();
}, executor);
```

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

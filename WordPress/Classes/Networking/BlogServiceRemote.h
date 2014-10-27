#import <Foundation/Foundation.h>

@class Blog;

typedef void (^OptionsHandler)(NSDictionary *options);
typedef void (^PostFormatsHandler)(NSDictionary *postFormats);
typedef void (^CategoriesHandler)(NSArray *categories);
typedef void (^PostsHandler)(NSArray *posts);
typedef void (^PagesHandler)(NSArray *pages);
typedef void (^MediaHandler)(NSArray *media);

@protocol BlogServiceRemote <NSObject>

// As methods are implemented for both REST and XML-RPC they should stop being optional
@optional

- (void)syncCategoriesForBlog:(Blog *)blog
                      success:(CategoriesHandler)success
                      failure:(void (^)(NSError *error))failure;

- (void)syncOptionsForBlog:(Blog *)blog
                   success:(OptionsHandler)success
                   failure:(void (^)(NSError *error))failure;

- (void)syncMediaLibraryForBlog:(Blog *)blog
                        success:(MediaHandler)success
                        failure:(void (^)(NSError *error))failure;

- (void)syncPostFormatsForBlog:(Blog *)blog
                       success:(PostFormatsHandler)success
                       failure:(void (^)(NSError *error))failure;

- (void)syncBlogMetadata:(Blog *)blog
            mediaSuccess:(MediaHandler)mediaSuccess
          optionsSuccess:(OptionsHandler)optionsSuccess
      postFormatsSuccess:(PostFormatsHandler)postFormatsSuccess
          overallSuccess:(void (^)(void))overallSuccess
                 failure:(void (^)(NSError *error))failure;


@end

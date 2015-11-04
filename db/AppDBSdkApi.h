//
//  AppDBSdkApi.h
//  Qianbao
//
//  Created by fengsh on 30/3/15.
//  Copyright (c) 2015年 fengsh. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DBSdkOperationApi <NSObject>

///安装数据库存放路径(不带库名) filepath 描述文件全路径
- (void)setupdb:(NSString *)dbname indir:(NSString *)dbdir useDescriptionfile:(NSString *)fullpath;

- (BOOL)executesql:(NSString *)sql,...;
- (NSArray *)querysql:(NSString *)sql,...;

///事务不能进行嵌套
- (BOOL)beginTransaction;
- (BOOL)rollback;
- (BOOL)commit;


@end

/**
 *  基类，继承此之后就可以用来作为某个库的操作对象直接处理即可
 */
@interface AppDBSdkApi : NSObject<DBSdkOperationApi>

@property (nonatomic, weak, readonly)   NSString          *dbName;
/**
 *  初始化一个库
 *
 *  @param dbname   库名称(不带扩展名)
 *  @param dbdir    库存放的路径
 *  @param fullpath 用于生成库的描述文件全路径
 */
- (instancetype)initWithDBName:(NSString *)dbname
                 withSetupPath:(NSString *)dbdir
            useDescriptionfile:(NSString *)fullpath;
@end


/**
 *  每个DAO对应的是一个数据库(包括有多张表)
 */
@interface AppDataBaseDao : AppDBSdkApi

@end

@interface AppDataBaseManager : NSObject
+ (AppDataBaseManager *)dbmanager;

/**
 *  添加一个数据库
 *
 */
- (void)add:(AppDataBaseDao *)database forKey:(NSString *)key;
/**
 *  删除一个数据库
 *
 */
- (void)removeForKey:(NSString *)key;
/**
 *  移除所有数据库
 */
- (void)removeAllDatabase;

/**
 *  获取一个数据库对象来对库进行相关操作。
 *
 */
- (AppDataBaseDao *)itemForKey:(NSString *)key;
@end

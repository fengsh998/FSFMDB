//
//  FMDBHelper.m
//  Qianbao
//
//  Created by fengsh on 20/3/15.
//  Copyright (c) 2015年 fengsh. All rights reserved.
//

#import "FMDBHelper.h"

#ifdef DEBUG
    #define DBLogger(fmt,...)       NSLog(fmt,##__VA_ARGS__)
#else
    #define DBLogger(...)
#endif

@implementation Sqlstatement

- (id)initWithSql:(NSString *)sql andParamter:(NSDictionary *)params
{
    if (self = [super init]) {
        self.sqlstatement = sql;
        self.sqlparamters = params;
    }
    return self;
}

@end


@implementation DBHelper
{
    FMDatabaseQueue *queue;
    BOOL            intrsactioning;
}

+ (DBHelper*)defalutHelper
{
    static dispatch_once_t dbhelper = 0;
    __strong static id _shared = nil;
    dispatch_once(&dbhelper, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (id)init
{
    self = [super init];
    if(self){
        intrsactioning = NO;
    }
    return self;
}

- (id)initWithDbpath:(NSString *)dbpath
{
    if (self = [super init]) {
        [self setDatabasePath:dbpath];
    }
    return self;
}

- (void)setDatabasePath:(NSString *)dbfilepath
{
    queue = [FMDatabaseQueue databaseQueueWithPath:dbfilepath];
}

- (BOOL)checkQueueReadyOK
{
    if (!queue) {
        DBLogger(@"DBHepler error : not to set database path.");
        return NO;
    }
    return YES;
}

- (BOOL)isok
{
    return queue ? YES : NO;
}

- (BOOL)execsql:(NSString *)sql withVAList:(va_list)valist
{
    __block BOOL ret = NO;
    
    [queue inDatabase:^(FMDatabase *db){
        
//        va_list args_copy;
//        //防止线程在执行过种中，外部参数被释放或串改了
//        va_copy(args_copy, valist);

        //在某些编译器下不能直接在block中使用外部参数的valist
        ret = [db executeUpdate:sql withVAList:valist/*args_copy*/];
        
//        va_end(args_copy);
    }];
    
    return ret;
}

- (NSArray *)querysql:(NSString *)sql withVAList:(va_list)valist
{
    __block NSMutableArray *results = [[NSMutableArray alloc] init];

    [queue inDatabase:^(FMDatabase *db) {
        //[db open];

//        va_list args_copy;
//        //防止线程在执行过种中，外部参数被释放或串改了
//        va_copy(args_copy, valist);
        
        FMResultSet *rs = [db executeQuery:sql withVAList:/*args_copy*/valist];
        while ([rs next])
        {
            [results addObject:[rs resultDictionary]];
        }
        
//        va_end(args_copy);
        //[db close];
    }];

    return results;
}

/**
 简单的执行一个sql语句
 */
- (BOOL)execsql:(NSString *)sql,...
{
    BOOL ret = NO;
    
    if ([self checkQueueReadyOK])
    {
        va_list args;
        va_start(args, sql);
        
        // va_list不能直接在block引用,使用了个变通方式,考虑到线程安全，内部对参数做了copy
        ret = [self execsql:sql withVAList:args];
        
        va_end(args);
    }
    
    return ret;
}

/**
 在事务中执行批量sql语句
 */
- (BOOL)execsqls:(NSArray *)sqls inTransaction:(BOOL)transaction
{
    if (![self checkQueueReadyOK]) {
        return NO;
    }
    
    __block BOOL ret = NO;
    
    if (transaction)
    {
        [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            //[db open];
            
            for (id sql in sqls)
            {
                if ([sql isKindOfClass:[NSString class]]) {
                    ret = [db executeUpdate:(NSString *)sql];
                }
                else if ([sql isKindOfClass:[Sqlstatement class]])
                {
                    Sqlstatement *sst = (Sqlstatement *)sql;

                    ret = [db executeUpdate:sst.sqlstatement withParameterDictionary:sst.sqlparamters];
                }
                
                if (!ret) {
                    *rollback = !ret;
                    break;
                }
            }
            
            //[db close];
        }];
        
    }
    else
    {
        [queue inDatabase:^(FMDatabase *db) {
            //[db open];
            for (id sql in sqls)
            {
                if ([sql isKindOfClass:[NSString class]]) {
                    ret = [db executeUpdate:(NSString *)sql];
                }
                else if ([sql isKindOfClass:[Sqlstatement class]])
                {
                    Sqlstatement *sst = (Sqlstatement *)sql;
                    
                    ret = [db executeUpdate:sst.sqlstatement withParameterDictionary:sst.sqlparamters];;
                }
                
                if (!ret) {
                    DBLogger(@"DBHelper error : execute sql [%@] failed.",sql);
                }
            }
            //[db close];
        }];
    }
    return ret;
}

/**
 执行查询操作
 */
- (NSArray *)querysql:(NSString *)sql,...
{
    if (![self checkQueueReadyOK]) {
        return nil;
    }
    
    va_list args;
    va_start(args, sql);
    
    NSArray *results = [self querysql:sql  withVAList:args];
    
    va_end(args);
    
    return results;
}

- (BOOL)beginTransaction
{
    @synchronized(self)
    {
        if (!intrsactioning)
        {
            [queue inDatabase:^(FMDatabase *db) {
                intrsactioning = [db beginTransaction];
            }];
            
            return intrsactioning;
        }
        return NO;
    }
}

- (BOOL)rollback
{
    @synchronized(self)
    {
        __block BOOL ret = NO;
        if (intrsactioning)
        {
            [queue inDatabase:^(FMDatabase *db) {
                ret = [db rollback];
            }];
            
            intrsactioning = !ret;
        }

        return ret;
    }
}

- (BOOL)commit
{
    @synchronized(self)
    {
        __block BOOL ret = NO;
        
        if (intrsactioning)
        {
            [queue inDatabase:^(FMDatabase *db) {
                 ret = [db commit];
            }];
            intrsactioning = !ret;
        }
        return ret;
    }
}

//- (void)test
//{
//    [queue inDatabase:^(FMDatabase *db) {
//        [db beginTransaction];
//        
//        
//        
//        [db commit];
//        [db rollback];
//    }];
//}



@end

/******************************************多库多线程操作********************************************/

@implementation FMDBHelper
{
    NSMutableDictionary         *dbOperatorQueues;
}

- (id)init
{
    self = [super init];
    if(self)
    {
        dbOperatorQueues = [[NSMutableDictionary alloc]init];
    }
    return self;
}

- (void)setDatebasePath:(NSString *)dbfilepath forKey:(NSString*)key
{
    FMDatabaseQueue *hasQueue = [dbOperatorQueues objectForKey:key];
    if (!hasQueue)
    {
        FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:dbfilepath];
        [dbOperatorQueues setObject:queue forKey:key];
    }
}

+ (FMDBHelper*)defalutHelper
{
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (FMDatabaseQueue *)getValidOperatorQueueForKey:(NSString *)key
{
    FMDatabaseQueue *queue = [dbOperatorQueues objectForKey:key];
    return queue;
}

- (void)inDatabase:(void(^)(FMDatabase *db))block inQueue:(FMDatabaseQueue *)queue
{
    [queue inDatabase:^(FMDatabase *db){
        block(db);
    }];
}

- (void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block inQueue:(FMDatabaseQueue *)queue
{
    [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        block(db,rollback);
    }];
}

- (BOOL)execsqlInDBKey:(NSString *)key withSQL:(NSString *)sql withParamters:(va_list)params
{
    __block BOOL ret = NO;
    FMDatabaseQueue *queue = [self getValidOperatorQueueForKey:key];
    if (queue) {
        [self inDatabase:^(FMDatabase *db) {
            
//            va_list args_copy;
//            //防止线程在执行过种中，外部参数被释放或串改了
//            va_copy(args_copy, params);
            
            ret = [db executeUpdate:sql withVAList:/*args_copy*/params];
            
//            va_end(args_copy);
            
        } inQueue:queue];
    }
    else
    {
        DBLogger(@"FMDBHelper error. Invalid operator queue.");
    }
    return ret;
}

- (NSArray *)querysqlInDBKey:(NSString *)key withSQL:(NSString*)sql withParamters:(va_list)params
{
    FMDatabaseQueue *queue = [self getValidOperatorQueueForKey:key];
    if (queue)
    {
        __block NSMutableArray *results = [[NSMutableArray alloc] init];
        [self inDatabase:^(FMDatabase *db) {
            
//            va_list args_copy;
//            //防止线程在执行过种中，外部参数被释放或串改了
//            va_copy(args_copy, params);
            
            FMResultSet *rs = [db executeQuery:sql withVAList:params/*args_copy*/];
            
            while ([rs next])
            {
                [results addObject:[rs resultDictionary]];
            }
            
//            va_end(args_copy);
        } inQueue:queue];
        
        return results;
    }
    else
    {
        DBLogger(@"FMDBHelper error. Invalid operator queue.");
    }
    return nil;
}

- (BOOL)execsqlForKey:(NSString *)key withSql:(NSString *)sql,...
{
    BOOL ret = NO;
    
    va_list args;
    va_start(args, sql);
    
    ret = [self execsqlInDBKey:key withSQL:sql withParamters:args];
    
    va_end(args);
    
    return ret;
}

- (NSArray *)querysqlForKey:(NSString *)key withSql:(NSString *)sql,...
{
    va_list args;
    va_start(args, sql);
    
    NSArray *results = [self querysqlInDBKey:key withSQL:sql withParamters:args];
    
    va_end(args);
    
    return results;
}

- (BOOL)execsqls:(NSArray *)sqls forKey:(NSString*)key inTransaction:(BOOL)transaction
{
    __block BOOL ret = NO;
    FMDatabaseQueue *queue = [self getValidOperatorQueueForKey:key];
    if (queue) {
        if (transaction) {
            [self inTransaction:^(FMDatabase *db, BOOL *rollback) {
                for (id sql in sqls)
                {
                    if ([sql isKindOfClass:[NSString class]]) {
                        ret = [db executeUpdate:(NSString *)sql];
                    }
                    else if ([sql isKindOfClass:[Sqlstatement class]])
                    {
                        Sqlstatement *sst = (Sqlstatement *)sql;
                        
                        ret = [db executeUpdate:sst.sqlstatement withParameterDictionary:sst.sqlparamters];
                    }
                    
                    ret = [db executeUpdate:sql];
                    if (!ret) {
                        *rollback = !ret;
                        break;
                    }
                }
            } inQueue:queue];
        }
        else
        {
            [self inDatabase:^(FMDatabase *db) {
                for (id sql in sqls)
                {
                    if ([sql isKindOfClass:[NSString class]]) {
                        ret = [db executeUpdate:(NSString *)sql];
                    }
                    else if ([sql isKindOfClass:[Sqlstatement class]])
                    {
                        Sqlstatement *sst = (Sqlstatement *)sql;
                        
                        ret = [db executeUpdate:sst.sqlstatement withParameterDictionary:sst.sqlparamters];
                    }
                    
                    ret = [db executeUpdate:sql];
                    if (!ret) {
                        DBLogger(@"FMDBHelper error : execute sql [%@] failed.",sql);
                    }
                }
            } inQueue:queue];
        }
    }
    else
    {
        DBLogger(@"FMDBHelper error. Invalid operator queue.");
    }

    return ret;
}

@end

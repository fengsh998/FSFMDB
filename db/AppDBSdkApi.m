//
//  AppDBSdkApi.m
//  Qianbao
//
//  Created by fengsh on 30/3/15.
//  Copyright (c) 2015年 fengsh. All rights reserved.
//
/**
 *  应用层使用的数据库操作SDK接口
 */

#import "AppDBSdkApi.h"
#import "DataBaseTools.h"
#import "FMDBHelper.h"

@interface AppDBSdkApi()<DataBaseToolsDelegate>
{
    DBHelper    *_dbhelper;
    NSString    *_dbname;
    NSString    *_dbsetuppath;
    BOOL        _dbreadyok;
}
@end

@implementation AppDBSdkApi

- (instancetype)init
{
    if (self = [super init]) {
        _dbreadyok = NO;
    }
    return self;
}

- (instancetype)initWithDBName:(NSString *)dbname
                 withSetupPath:(NSString *)dbdir
            useDescriptionfile:(NSString *)fullpath
{
    if (self = [super init])
    {
        _dbreadyok = NO;
        [self setupdb:dbname indir:dbdir useDescriptionfile:fullpath];
    }
    return self;
}

- (void)setupdb:(NSString *)dbname indir:(NSString *)dbdir useDescriptionfile:(NSString *)fullpath
{
    _dbname = dbname;
    _dbsetuppath = dbdir;
    
    [self todoCreateOrUpdataDB:_dbname byDescfile:fullpath];
}

- (NSURL *)getSetupPath
{
    if (_dbsetuppath && _dbname) {
        NSString *setup = [[_dbsetuppath stringByAppendingPathComponent:_dbname]stringByAppendingString:@".sqlite"];
        return [NSURL fileURLWithPath:setup];
    }
    
    return nil;
}

- (DBHelper *)dbhelper
{
    if (!(_dbhelper)) {
        NSURL *dbpath = [self getSetupPath];
        if (dbpath)
        {
            _dbhelper = [[DBHelper alloc]initWithDbpath:dbpath.path];
            _dbreadyok = _dbhelper.isok;
        }
    }
    return _dbhelper;
}

- (NSString*)dbName
{
    return _dbname;
}

- (void)todoCreateOrUpdataDB:(NSString *)dbname byDescfile:(NSString *)fullpath
{
    DataBaseTools *tools = [[DataBaseTools alloc]init];
    tools.delegate = self;
    if (!_dbsetuppath)
    {   //如果用户未指定安装路径，使用默认的
        _dbsetuppath = [tools getDefaultSetupDBPath];
    }
    [tools CreateOrUpdateSpecialDBFromDescriptionFile:fullpath withDBName:dbname
                                             withMode:createmodeUpdateWhenExsistDB];
}

- (BOOL)executesql:(NSString *)sql,...
{
    BOOL ret = NO;
    DBHelper *handle = self.dbhelper;
    if (_dbreadyok) {
        
        va_list args;
        va_start(args, sql);
        
        ret = [handle execsql:sql withVAList:args];
        
        va_end(args);
    }
    
    return ret;
}

- (NSArray *)querysql:(NSString *)sql,...
{
    NSArray *results = nil;
    DBHelper *handle = self.dbhelper;
    if (_dbreadyok) {
        
        va_list args;
        va_start(args, sql);
        
        results = [handle querysql:sql withVAList:args];
        
        va_end(args);
    }
    
    return results;
}

///事务不能进行嵌套
- (BOOL)beginTransaction
{
    return [self.dbhelper beginTransaction];
}
- (BOOL)rollback
{
    return [self.dbhelper rollback];
}

- (BOOL)commit
{
    return [self.dbhelper commit];
}

#pragma mark - tools delegate
- (NSURL *)setupDbDirFromDBname:(NSString *)dbname
{
    //指定安装路径
    return [self getSetupPath];
}

@end

@implementation AppDataBaseDao

- (id)init
{
    if (self = [super init]) {
        
    }
    return self;
}

@end

@interface AppDataBaseManager ()
{
    NSMutableDictionary                                                 *_dblist;
}
@end

@implementation AppDataBaseManager

+ (AppDataBaseManager *)dbmanager
{
    static AppDataBaseManager *dbmanagerinstance = nil;
    static dispatch_once_t dbmanagertoke = 0;
    dispatch_once(&dbmanagertoke, ^{
        if (!dbmanagerinstance) {
            dbmanagerinstance = [[AppDataBaseManager alloc]init];
        }
    });
    
    return dbmanagerinstance;
}

- (id)init
{
    if (self = [super init]) {
        _dblist = [[NSMutableDictionary alloc]init];
    }
    return self;
}

- (void)add:(AppDataBaseDao *)database forKey:(NSString *)key
{
    [_dblist setObject:database forKey:key];
}

- (void)removeForKey:(NSString *)key
{
    [_dblist removeObjectForKey:key];
}

- (void)removeAllDatabase
{
    [_dblist removeAllObjects];
}

- (AppDataBaseDao *)itemForKey:(NSString *)key
{
    return (AppDataBaseDao *)[_dblist objectForKey:key];
}

@end

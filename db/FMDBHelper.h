//
//  FMDBHelper.h
//  Qianbao
//
//  Created by fengsh on 20/3/15.
//  Copyright (c) 2015年 fengsh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"

/*
 NSString *sql = @"insert into users values(:id, :name, :age)";
 
 NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"id123", @"id", @"kyfxbl", @"name", 23, @"age", nil];
 */
@interface Sqlstatement : NSObject

/// sql语句使用:XX作为参数
@property (nonatomic, strong) NSString              *sqlstatement;
/// sql语句对应的参数值，字典key为参数名
@property (nonatomic, strong) NSDictionary          *sqlparamters;

- (id)initWithSql:(NSString *)sql andParamter:(NSDictionary *)params;
@end


/**
    单库多线程操作
    可使用继承的方式来扩展多库操作
 */
@interface DBHelper : NSObject

@property (nonatomic,readonly)  BOOL    isok;

+ (DBHelper*)defalutHelper;

- (id)initWithDbpath:(NSString *)dbpath;

- (void)setDatabasePath:(NSString *)dbfilepath;
/**
 简单的执行一个sql语句
 */
- (BOOL)execsql:(NSString *)sql,...;
- (BOOL)execsql:(NSString *)sql withVAList:(va_list)valist;
/**
 执行查询操作
 */
- (NSArray *)querysql:(NSString *)sql,...;
- (NSArray *)querysql:(NSString *)sql withVAList:(va_list)valist;
/**
 在事务中执行批量sql语句(这里的sql参数都是字符类型)
 如果不在事务中，侧某个语句有错将不会回滚
 在批量执行时,如果果不在事务中,return 值不能作为全部成功或失败判断
 为解决sql中特殊参数在批量处理中不能转为字符的语句，因而在sqls的数组中可以添加
 Sqlstatement 对象来处理语句对应的特殊参数处理。
 */
- (BOOL)execsqls:(NSArray *)sqls inTransaction:(BOOL)transaction;

///事务不能进行嵌套
- (BOOL)beginTransaction;
- (BOOL)rollback;
- (BOOL)commit;

@end


/**
    多库多线程操作
 */
@interface FMDBHelper : NSObject

+ (FMDBHelper*)defalutHelper;

/**
   dbfilepath db文件全路径
   key为操作对应db所设的唯一key
 */
- (void)setDatebasePath:(NSString *)dbfilepath forKey:(NSString*)key;

- (BOOL)execsqlForKey:(NSString *)key withSql:(NSString *)sql,...;
- (BOOL)execsqlInDBKey:(NSString *)key withSQL:(NSString *)sql withParamters:(va_list)params;
- (NSArray *)querysqlForKey:(NSString *)key withSql:(NSString *)sql,...;
- (NSArray *)querysqlInDBKey:(NSString *)key withSQL:(NSString*)sql withParamters:(va_list)params;

- (BOOL)execsqls:(NSArray *)sqls forKey:(NSString*)key inTransaction:(BOOL)transaction;



@end

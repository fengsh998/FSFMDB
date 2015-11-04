//
//  DataBaseTools.m
//  Qianbao
//
//  Created by fengsh on 21/3/15.
//  Copyright (c) 2015年 fengsh. All rights reserved.
//
/*
    视图与触发器直接使用语句.
 
    字段类型

 */

#import <UIKit/UIKit.h>
#import "DataBaseTools.h"
#import "FMDBHelper.h"
#import <CommonCrypto/CommonDigest.h>

//plis文件编辑时使用的key值
NSString * dic_key_dbStaticList                     = @"StaticDBList";
NSString * dic_key_dbDynamicList                    = @"DynamicDBList";
NSString * dic_key_dbName                           = @"DBName";
NSString * dic_key_dbVersion                        = @"DBVersion";
NSString * dic_key_dbTables                         = @"DBTables";
NSString * dic_key_dbViews                          = @"DBViews";
NSString * dic_key_dbTriggers                       = @"DBTriggers";
NSString * dic_key_dbTableName                      = @"DBTableName";
NSString * dic_key_dbFields                         = @"DBFields";
NSString * dic_key_dbFieldName                      = @"FieldName";
NSString * dic_key_IndexColumnDESC                  = @"ColumnDESC";
NSString * dic_key_IndexColumnASC                   = @"ColumnASC";
/*
  描述文档中字段类型只可选取
 TEXT,REAL,INTEGER,BLOB,VARCHAR,FLOAT,DOUBLE,DATE,TIME,BOOLEAN,TIMESTAMP,BINARY
 */
NSString * dic_key_dbFieldType                      = @"FieldType";
/*
  描述文档中字段约束只可选取的字符串(一个或多个用,号分开),暂支持这些
  PRIMARY KEY,AUTOINCREMENT ,NOT NULL,UNIQUE,DEFAULT 1
 */
NSString * dic_key_dbFieldConstraint                = @"FieldConstraint";
NSString * dic_key_dbIndexs                         = @"DBIndexs";
NSString * dic_key_dbFieldIndexName                 = @"FieldIndexName";
NSString * dic_key_dbFieldIndexType                 = @"FieldIndexType";

#pragma mark - 分隔符声明
#define conjoin                 @"^_^"
#define dbext                   @".sqlite"

#pragma mark - 通知名声明
NSString * ntf_name_createorupdate_compeleted   = @"ntf_db_create_or_update_finish";

//内部比对时使用的key
#pragma mark - 私有比对key
NSString * dic_key_createtables                 = @"CREATE_TABLES";
NSString * dic_key_createindexs                 = @"CREATE_INDEXS";
NSString * dic_key_createviews                  = @"CREATE_VIEWS";
NSString * dic_key_createtriggers               = @"CREATE_TRIGGERS";
NSString * dic_key_altertables                  = @"ALTER_TABLES";
NSString * dic_key_droptables                   = @"DROP_TABLES";
NSString * dic_key_dropindexs                   = @"DROP_INDEXS";
NSString * dic_key_dropviews                    = @"DROP_VIEWS";
NSString * dic_key_droptriggers                 = @"DROP_TRIGGERS";
//数据迁移的字段key
NSString * dic_key_select_field                 = @"EXPORT_FIELDS";
//新字段修改的key
NSString * dic_key_alter_field                  = @"ALTER_FIELDS";
//当前库中的视图
NSString * dic_key_current_views                = @"CURRENT_VIEWS";
NSString * dic_key_current_triggers             = @"CURRENT_TRIGGERS";



/**************************************SQL 语句宏***************************************/
#pragma mark - 数据库定义及操作SQL
#define CREATE_TABLE_VERSIONBACK_SQL    (@"CREATE TABLE IF NOT EXISTS APP_DB_VERSION_BACKUP (\
VERSIONID INTEGER PRIMARY KEY AUTOINCREMENT,VERSION VARCHAR,METADATA BLOB)")
//只存最新的一条备分数据
#define INSERT_INTO_VERSIONBACK         (@"REPLACE INTO APP_DB_VERSION_BACKUP \
(VERSIONID,VERSION,METADATA) VALUES (1,:V1,:V2)")
#define GET_VERSION_INFO                (@"SELECT VERSION,METADATA FROM APP_DB_VERSION_BACKUP \
WHERE VERSIONID = 1")

/*****************************DDL 语句****************************/
///创建表(参1表名,参2表的所有字段及类型)
#define CREATE_TABLE_FMT_SQL            (@"CREATE TABLE IF NOT EXISTS %@ (%@)")
///创建视图
#define CREATE_VIEW_FMT_SQL             @"CREATE VIEW IF NOT EXISTS \"%@\" AS \"%@\"")
///创建索引
#define CREATE_INDEX_FMT_SQL            (@"CREATE %@ INDEX IF NOT EXISTS %@ ON %@ (%@)")
///修改表
#define ALTER_TABLE_ADD_COLUMN_SQL      (@"ALTER TABLE \"%@\" ADD COLUMN \"%@\"")
///导数据(参1为目标表名,参2为目标表名中的字段名,参3为需要导的字段,参4导出表)
#define EXPORT_DATA_DEST_TABLE          (@"INSERT INTO %@(%@) SELECT %@ FROM %@")

///重健索引
#define REBUILDINDEX                    (@"REINDEX")
///重建当前主数据库中X表的所有索引。
#define REBUILDINDEX_IN_TABLENAME       (@"REINDEX %@")
///重建当前主数据库中名称为X的索引。
#define REBUILDINDEX_IN_INDEXNAME       (@"REINDEX %@")

///缓存数据清理(sqlite命令，针对当频繁有增，删，改数据操作后产生的开销进行清理)
#define CLEAN_CACHE_DATA                (@"VACUUM");

/*重命名表名
 影响到该表依赖的触发器，视图，必须重建
 对索引无影响
 */
#define RENAME_TABLENAME_SQL            (@"ALTER TABLE \"%@\" RENAME TO \"%@\"")

#define DROP_TYPE_SQL(X)                (@"DROP "#X" IF EXISTS %@")
///删除表
#define DROP_TABLE_SQL                  (DROP_TYPE_SQL(TABLE))
///删除视图
#define DROP_VIEW_SQL                   (DROP_TYPE_SQL(VIEW))
///删除触发器
#define DROP_TRIGGER_SQL                (DROP_TYPE_SQL(TRIGGER))
///删除索引
#define DROP_INDEX_SQL                  (DROP_TYPE_SQL(INDEX))

//不能直接用语句来修改sqlite_master表中的数据。只可以查
#define SELECT_ALL_TYPE_SQL(x)          (@"SELECT * FROM sqlite_master WHERE type = '"#x"'")
#define SELECT_ALL_VIEWS_SQL            (SELECT_ALL_TYPE_SQL(view))
#define SELECT_ALL_TRIGGERS_SQL         (SELECT_ALL_TYPE_SQL(trigger))
#define SELECT_ALL_TABLE_SQL            (SELECT_ALL_TYPE_SQL(table))

//重置所有表的自增序号从1开始
#define RESET_SEQUENCE(tablename)       (@"DELETE FROM sqlite_sequence WHERE name = '"#tablename"'")
//要是想重置所有表
#define RESET_SEQUENCE_ALL              (@"DELETE FROM sqlite_sequence")

//任意的x成NSString
#define MSG_STR(x) @"" #x


typedef NS_ENUM(NSInteger, ToolErrorType)
{
    operationSuccess            = 0x0,
    parsefileFailed             = 0x1,
    parsedataFailed             = 0x1 << 1,         //解释描述文件失败
    dbNotFoundFailed            = 0x1 << 2,
    emptyDBListFailed           = 0x1 << 3,         //无可创建的数据库
    allDBCreateFailed           = 0x1 << 4,         //所有库创建失败
    partDBCreateFailed          = 0x1 << 5,         //部分库创建失败
    createorupdateFailed        = 0x1 << 6          //sql语句操作失败
};

#pragma mark - 实现部分
@implementation DataBaseTools

+ (DataBaseTools *)defaultTools
{
    static dispatch_once_t dbmanger = 0;
    __strong static id _shareddbmanger = nil;
    dispatch_once(&dbmanger, ^{
        _shareddbmanger = [[self alloc] init];
    });
    return _shareddbmanger;
}

#pragma mark - 辅助函数
/**
 *  将数组或字典转为NSData
 *
 *  @param object 字典或数组对象
 *
 *  @return
 */
- (NSData *)dictionaryOrArrayConvert2Data:(id)object
{
    if ([object isKindOfClass:[NSDictionary class]] ||
        [object isKindOfClass:[NSArray class]])
    {
        NSError *parseError = nil;
        NSData  *jsonData = [NSJSONSerialization dataWithJSONObject:object
                                                            options:NSJSONWritingPrettyPrinted
                                                              error:&parseError];
        if (!parseError)
        {
            return jsonData;
        }
    }
    return nil;
}

/**
 *  全路径文件判断
 *
 *  @param fullfilepath 全路径文件
 *
 *  @return
 */
- (BOOL)fileExsistPath:(NSString *)fullfilepath
{
    return [[NSFileManager defaultManager]fileExistsAtPath:fullfilepath];
}

/**
 *  返回默认数据库存放路径~/documents
 *
 *  @return
 */
- (NSString *)getDefaultSetupDBPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentdir = [paths objectAtIndex:0];
    return documentdir;
}

//从A中去除B中有的元素
- (NSArray *)getElements:(NSArray *)A notContains:(NSArray *)B
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", B];
    return [A filteredArrayUsingPredicate:predicate];
}

//获取打包目录中的plist文件路径
//filename 不带后缀
- (NSString *)getPlistPathInBundleOfFilename:(NSString *)filename
{
    NSString *path = [[NSBundle mainBundle] pathForResource:
                      filename ofType:@"plist"];
    return path;
}

//求出两数组中相同的元素。元素必须为字符串(求交值)
- (NSArray *)getSameElement:(NSArray *)A withB:(NSArray *)B
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF IN %@", B];
    return [A filteredArrayUsingPredicate:predicate];
}

- (NSDictionary *)jsonDataConvertToDictionary:(NSData *)jsondata
{
    NSError* error;
    NSDictionary* json = [NSJSONSerialization
                          JSONObjectWithData:jsondata
                          options:kNilOptions
                          error:&error];
    return !error ? json : nil;
}

- (NSString*) sha1:(NSString*)input
{
    const char *cstr = [input cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:input.length];
    
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return output;
    
}

/**
 *  将数组或字典转换成字符串后进行hash取值
 *
 *  @param arrordic 数组或字典对象
 * 
 *  使用此方法时如果是字典，字典中的key顺序及值的结构必须一模一样才能得到相同的hash.尽管两个字典中的结果是一样，但
 *  key的顺序和value的顺序不样。得到的hash就不样。
 *
 *  @return
 */
- (NSUInteger)stringArrayOrDictionaryConvert2hashvalue:(id)arrordic
{
    NSString *ss = [self stringArrayOrDictionaryConvert2:arrordic];
    ss = [ss stringByReplacingOccurrencesOfString:@" " withString:@""];
    ss = [ss stringByReplacingOccurrencesOfString:@"\\n" withString:@""];
    ss = [ss stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    ss = [ss stringByReplacingOccurrencesOfString:@"\\t" withString:@""];
    ss = [ss stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    
    //由于字串过常时，小改一部分nsstring的hash有可能一样。所以使用sha1来让保证小改动也识别出不同
    ss = [self sha1:ss];
    
    if (ss.length > 0) {
        return ss.hash;
    }
    
    return NSNotFound;
}

- (NSString *)stringArrayOrDictionaryConvert2:(id)arrordic
{
    NSData * dt = [self dictionaryOrArrayConvert2Data:arrordic];
    if (dt) {
        NSString *arrstring = [[NSString alloc] initWithData:dt encoding:NSUTF8StringEncoding];
        return [arrstring lowercaseString];
    }
    return nil;
}

#pragma mark - 工具类的测试入口
- (void)setup
{
    NSString *plistfile = [self getPlistPathInBundleOfFilename:@"dbdesc1"];
    

    //[self CreateDBByDescriptionFile:plistfile withLoadType:dbloadtypeAllDB];
    NSInteger ret = [self CreateOrUpdateDBByDescriptionFile:plistfile useLoadType:dbloadtypeAllDB
                                   withMode:createmodeUpdateWhenExsistDB];
    NSLog(@"ret == %ld",(long)ret);
    //[self CreateOrUpdateSpecialDBFromDescriptionFile:plistfile withDBName:@"db2" withMode:createmodeUpdateWhenExsistDB];
}

#pragma mark - 解释数据库描述文件
/**
 *  解释数据库描述文件
 *
 *  @param filepath 描述文件的路径(文件为plist文件)
 *
 *  @return 生成的Dic数据
 */
- (NSDictionary *)parseDBDescriptionFile:(NSString *)filepath
{
    if (![self fileExsistPath:filepath])
    {
        NSLog(@"DataBaseManager Error : not found filepath %@ ",filepath);
        return nil;
    }
    
    //读取描述文件内容，转为dic对象
    NSDictionary * allDbsInfo = [NSDictionary dictionaryWithContentsOfFile:filepath];
    
    return allDbsInfo;
}

/**
 *  @param pliststructdata 必须是从plist文件中读取的
 *
 *  @return
 */
- (NSDictionary *)parseDBDescriptionData:(NSData *)pliststructdata
{
    CFPropertyListRef list = NULL;

#if (__IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_8_0)
        list = CFPropertyListCreateFromXMLData(kCFAllocatorDefault,
                                               (__bridge CFDataRef)pliststructdata,
                                               kCFPropertyListImmutable,
                                               NULL);
#else
        CFPropertyListFormat dataFormat = 0;
        list = CFPropertyListCreateWithData(kCFAllocatorDefault,
                                            (__bridge CFDataRef)pliststructdata,
                                            kCFPropertyListImmutable,
                                            &dataFormat,
                                            NULL);
#endif
    
    //CFRelease(list);
    return (__bridge NSDictionary *)(list);
}

#pragma mark - 创建库函数
/**
 *  通描述文件来创建数据库
 *
 *  @param plistfile dbdesc.plist文件
 */
- (NSInteger)CreateDBByDescriptionFile:(NSString *)plistfile withLoadType:(DBLoadType)loadtype
{
    //通过描述文件转为dic进行操作
    NSDictionary *dbsDic = [self parseDBDescriptionFile:plistfile];
    if (dbsDic)
    {
        return [self CretaeDBByDictionary:dbsDic withLoadType:loadtype];
    }
    else
    {
        return parsefileFailed;
    }
    
    return operationSuccess;
}

- (NSInteger)CreateDBByDescriptionData:(NSData *)plistdata withLoadType:(DBLoadType)loadtype
{
    NSDictionary *dbsDic = [self parseDBDescriptionData:plistdata];
    if (dbsDic)
    {
        return [self CretaeDBByDictionary:dbsDic withLoadType:loadtype];
    }
    else
    {
        return parsedataFailed;//解释db数据出错
    }
    
    return operationSuccess;
}

/**
 *  根据类型来创建库
 *
 *  @param plistdictionary
 *  @param loadtype
 */
- (NSInteger)CretaeDBByDictionary:(NSDictionary *)plistdictionary withLoadType:(DBLoadType)loadtype
{
    NSArray *needcreates = [self getNeedCreateDB:plistdictionary ByLoadType:loadtype];
    
    if (needcreates.count > 0)
    {
        return [self todoMakeDB:needcreates withForce:NO];
    }
    else
    {
        return emptyDBListFailed;//没有任何需要创建的库
    }
    
    return operationSuccess;
}

/// 按类型过虑出需要创建的库
- (NSArray *)getNeedCreateDB:(NSDictionary *)plistdictionary ByLoadType:(DBLoadType)loadtype
{
    NSMutableArray *needcreates = [NSMutableArray array];
    switch (loadtype) {
        case dbloadtypeStaticDB: //只解释静态创库的进行生成
        {
            //获取字典中所有需要创建的库
            NSArray *dbs = [plistdictionary objectForKey:dic_key_dbStaticList];
            [needcreates addObjectsFromArray:dbs];
        }
            break;
        case dbloadtypeDynamicDB: //只解释延迟创建的库进行生成
        {
            NSArray *dbs = [plistdictionary objectForKey:dic_key_dbDynamicList];
            [needcreates addObjectsFromArray:dbs];
        }
            break;
            
        default: //静态，动态进行创建
        {
            NSArray *dbs = [plistdictionary objectForKey:dic_key_dbStaticList];
            NSArray *ddbs = [plistdictionary objectForKey:dic_key_dbDynamicList];
            
            [needcreates addObjectsFromArray:dbs];
            [needcreates addObjectsFromArray:ddbs];
        }
            break;
    }
    
    return needcreates;
}

/**
 *  构建DB
 *
 *  @param dbs DB数组，可以一次创建多个
 */
- (NSInteger)todoMakeDB:(NSArray *)dbs withForce:(BOOL)force
{
    NSString *defaultdir = [self getDefaultSetupDBPath];
    
    NSInteger total = 0;
    
    for (NSDictionary *item in dbs)
    {
        @autoreleasepool {
            NSString *dbname = [item objectForKey:dic_key_dbName];
            NSURL *setuppath = nil;
            //由委托来设置路径
            if ([self.delegate respondsToSelector:@selector(setupDbDirFromDBname:)])
            {
                setuppath = [self.delegate setupDbDirFromDBname:dbname];
            }
            if (!setuppath)
            {
                setuppath = [NSURL fileURLWithPath:[defaultdir stringByAppendingPathComponent:
                                                    [NSString stringWithFormat:@"%@%@",dbname,dbext]]];
            }
            
            NSURL *bkurl = nil;
            
            if (force)
            {
                //重建前做好备分，以备容错处理。
                bkurl = [self todoBackupDB:setuppath];
                //[self todoRemoveDB:setuppath];
            }
#ifdef DEBUG
            NSLog(@"setuppath = %@",setuppath);
#endif
            //创建工作
            NSInteger ret = [self todoCreateDB:item inPath:setuppath];
            if (ret > 0)
            {
                total++;
                //有失败，且是强制升级失败的
                if (bkurl) {
                    [self todoRemoveDB:setuppath];//删除创建失败的文件
                    [self todoRestoreDB:bkurl toSrc:setuppath];
                }
            }
            else if (bkurl)
            {   //重建成功，需要删除备分文件
                [self todoRemoveDB:bkurl];
            }
        }
    }
    
    return ((total == dbs.count) && (total > 0)) ? allDBCreateFailed : (total > 0) ? partDBCreateFailed : operationSuccess;
}

- (Sqlstatement *)makeVersionInfoStatmentByDB:(NSDictionary *)db
{
    //给表添加一个版本记录表
    NSData *dbinfo = [self dictionaryOrArrayConvert2Data:db];
    NSString *version = [db objectForKey:dic_key_dbVersion];
    NSDictionary *params = @{@"V1":version,@"V2":dbinfo};
    Sqlstatement *st = [[Sqlstatement alloc]initWithSql:INSERT_INTO_VERSIONBACK andParamter:params];
    return st;
}

/**
 *  创建一个库
 *
 *  @param db        库的dic结构
 *  @param setuppath 库生成的存放的路径
 */
- (NSInteger)todoCreateDB:(NSDictionary *)db inPath:(NSURL *)setuppath
{
    //拿到整个库的sql
    NSMutableArray *sqls = (NSMutableArray *)[self toMakeSqlByDBDictionary:db];
    
    if (sqls) {
        Sqlstatement *st = [self makeVersionInfoStatmentByDB:db];
        [sqls addObject:st];
        
        BOOL success = [self toCreateDBBySqls:sqls inPath:setuppath];
        if (success) {
            NSLog(@"Database %@ setup success.",[db objectForKey:dic_key_dbName]);
            [self todoFinishDelegateOrNotification:YES];
        }
        else
        {
            NSLog(@"Database %@ setup failed.",[db objectForKey:dic_key_dbName]);
            [self todoFinishDelegateOrNotification:NO];
            return createorupdateFailed;
        }
    }
    else
    {
        NSLog(@"无任何更新,结束。");
        //无任何sql执行。则认为Ok
        [self todoFinishDelegateOrNotification:YES];
    }
    
    return operationSuccess;
}

/**
 *  构造数据库创建的表，索引，视图，触发器等语句
 *
 *  @param db
 *
 *  @return sql数组
 */
- (NSArray *)toMakeSqlByDBDictionary:(NSDictionary *)db
{
    NSMutableArray *sqls = [NSMutableArray array];
    
    //获取表名
    NSArray *tables = [db objectForKey:dic_key_dbTables];
    for (NSDictionary *table in tables)
    {
        NSString *tablename         = [table objectForKey:dic_key_dbTableName];
        NSArray  *fieldsinfo        = [table objectForKey:dic_key_dbFields];
        NSString *fields            = [self serializationFieldsFromArray:fieldsinfo];
        
        NSString *createtablesql = [NSString stringWithFormat:CREATE_TABLE_FMT_SQL,tablename,fields];
        //先建表，再建索引
        [sqls addObject:[createtablesql uppercaseString]];
    }
    
    //获取表中需要的创建的索引
    NSArray  *indexs            = [db objectForKey:dic_key_dbIndexs];
    NSArray *createindexsqls    = [self makeIndexSqls:indexs];
    
    if (createindexsqls.count > 0) {
        [sqls addObjectsFromArray:createindexsqls];
    }
    
    //读取视图的sql语句
    NSArray * viewsqls = [db objectForKey:dic_key_dbViews];
    if (viewsqls.count > 0) {
        [sqls addObjectsFromArray:viewsqls];
    }
    
    //读取触发器的sql语句
    NSArray * triggersqls = [db objectForKey:dic_key_dbTriggers];
    if (triggersqls.count > 0) {
        [sqls addObjectsFromArray:triggersqls];
    }
    
    //添加一个版本记录的表用于记录本次版本特征
    NSString *versionbackup = CREATE_TABLE_VERSIONBACK_SQL;
    [sqls addObject:versionbackup];
    
    return sqls.count > 0 ? sqls : nil;
}

- (NSArray *)makeIndexSqls:(NSArray *)indexs
{
    NSMutableArray *indexsqls = [NSMutableArray array];
    
    for (NSDictionary *index in indexs)
    {
        NSString *type = @"";
        //必填
        NSString *tablename = [index objectForKey:dic_key_dbTableName];
        NSString *indexname = [index objectForKey:dic_key_dbFieldIndexName];
        NSString *indexFieldname = [index objectForKey:dic_key_dbFieldName];
        //可选
        NSString *indextype = [index objectForKey:dic_key_dbFieldIndexType];
        if (indextype) {
            type = @"UNIQUE";
        }
        
        NSString *desc = [index objectForKey:dic_key_IndexColumnDESC];
        NSString *asc = [index objectForKey:dic_key_IndexColumnASC];
        
        NSMutableArray *ar = [NSMutableArray array];
        if (desc.length > 0) {
            desc = [NSString stringWithFormat:@"%@ DESC",desc];
            [ar addObject:desc];
        }
        
        if (asc.length > 0) {
            asc = [NSString stringWithFormat:@"%@ DESC",asc];
            [ar addObject:asc];
        }
        
        if (ar.count > 0) {
            indexFieldname = [ar componentsJoinedByString:@","];
        }
        
        NSString *sql = [NSString stringWithFormat:CREATE_INDEX_FMT_SQL,type,
                         indexname,tablename,indexFieldname];
        [indexsqls addObject:sql];
    }
    
    return indexsqls.count > 0 ? indexsqls : nil;
}

/**
 *  将字段进行序列化为string
 *
 *  @param fields
 *
 *  @return
 */
- (NSString *)serializationFieldsFromArray:(NSArray *)fields
{
    NSMutableArray *fieldlist = [NSMutableArray array];
    
    for (NSDictionary *field in fields)
    {
        //必取字段
        NSString *fieldname         = [[field objectForKey:dic_key_dbFieldName]uppercaseString];
        
        NSString *fieldtype         = [[field objectForKey:dic_key_dbFieldType]uppercaseString];
        
        NSString *sqlpart = [NSString stringWithFormat:@"%@ %@ ",fieldname,fieldtype];
        
        //可选
        NSString *fieldconstraint   = [field objectForKey:dic_key_dbFieldConstraint];
        if (fieldconstraint) {
            
            NSArray * constraint = [fieldconstraint componentsSeparatedByString:@","];
            for (NSString *item in constraint)
            {
                sqlpart = [sqlpart stringByAppendingString:[item uppercaseString]];
            }
        }
        
        [fieldlist addObject:sqlpart];
    }
    
    if (fieldlist.count > 0) {
        return [fieldlist componentsJoinedByString:@","];
    }
    
    return nil;
}

- (DBHelper *)getThreadSafeDBHelperByDBPath:(NSString *)path
{
    return [[DBHelper alloc]initWithDbpath:path];
}

// 30 张表 0.01秒左右
- (BOOL)toCreateDBBySqls:(NSArray *)sqls inPath:(NSURL *)dbsetuppath
{
#ifdef DEBUG
    double start = CFAbsoluteTimeGetCurrent();
#endif
    
    DBHelper *tmp = [self getThreadSafeDBHelperByDBPath:dbsetuppath.path];
    BOOL ok = [tmp execsqls:sqls inTransaction:YES];
    
#ifdef DEBUG
    double end = CFAbsoluteTimeGetCurrent();
    NSLog(@"创建数据库用时 : %f",end - start);
#endif
    
    return ok;
}


#pragma mark - 创建或升级数据库
- (NSInteger)CreateOrUpdateDBByDescriptionFile:(NSString *)plistfile useLoadType:(DBLoadType)loadtype
                                 withMode:(DBCreateMode)createmode
{
    NSDictionary *dbinfo = [self parseDBDescriptionFile:plistfile];
    if (dbinfo) {
        return [self CreateOrUpdateDBByDictionary:dbinfo useLoadType:loadtype withMode:createmode];
    }
    else
    {
        return parsefileFailed;
    }
}

- (NSInteger)CreateOrUpdateDBByDescriptionData:(NSData *)plistdata useLoadType:(DBLoadType)loadtype
                                 withMode:(DBCreateMode)createmode
{
    NSDictionary *dbinfo = [self parseDBDescriptionData:plistdata];
    if (dbinfo) {
        return [self CreateOrUpdateDBByDictionary:dbinfo useLoadType:loadtype withMode:createmode];
    }
    else
    {
        return parsedataFailed;
    }
}

- (NSInteger)CreateOrUpdateSpecialDBFromDescriptionFile:(NSString *)plistfile withDBName:(NSString *)dbname
                                          withMode:(DBCreateMode)createmode
{
    NSDictionary *dbinfo = [self parseDBDescriptionFile:plistfile];
    if (dbinfo) {
        NSArray *needcreates = [self filerSpecialDB:dbinfo atFilerNames:[NSArray arrayWithObject:dbname]];
        if (needcreates.count > 0) {
            return [self todoCreateOrUpdateDB:needcreates useMode:createmode];
        }
        else
        {
            NSLog(@"ERROR : do not found [%@] in [%@]",dbname,plistfile);
            return dbNotFoundFailed;
        }
    }
    else
    {
        return parsefileFailed;
    }
}

- (NSInteger)CreateOrUpdateSpecialDBFromDescriptionData:(NSData *)plistdata withDBName:(NSString *)dbname
                                          withMode:(DBCreateMode)createmode
{
    NSDictionary *dbinfo = [self parseDBDescriptionData:plistdata];
    if (dbinfo) {
        NSArray *needcreates = [self filerSpecialDB:dbinfo atFilerNames:[NSArray arrayWithObject:dbname]];
        if (needcreates.count > 0) {
            return [self todoCreateOrUpdateDB:needcreates useMode:createmode];
        }
        else
        {
            NSLog(@"ERROR : do not found [%@] in DescriptionData",dbname);
            return dbNotFoundFailed;
        }
    }
    else
    {
        return parsedataFailed;
    }
}

- (NSInteger)CreateOrUpdateDBByDictionary:(NSDictionary *)dbstruct useLoadType:(DBLoadType)loadtype
                            withMode:(DBCreateMode)createmode
{
    NSArray *needcreates = [self getNeedCreateDB:dbstruct ByLoadType:loadtype];
    if (needcreates.count > 0) {
        return [self todoCreateOrUpdateDB:needcreates useMode:createmode];
    }
    else
    {
        return emptyDBListFailed;
    }
}

- (NSInteger)todoCreateOrUpdateDB:(NSArray *)dbs useMode:(DBCreateMode)mode
{
    switch (mode) {
        case createmodeUpdateWhenExsistDB: //比对升级
        {
            //进行库比对处理
            return [self todoUpdateDBs:dbs];
        }
            break;
        case createmodeForceCreateDB: //清空原库，重新生成
        {
            //直接删除库，没有什么好想的。
            return [self todoMakeDB:dbs withForce:YES];
        }
            break;
            
        default:
        {
            return [self todoMakeDB:dbs withForce:NO];
        }
            break;
    }
}

// 过滤出特定需要创建的库
- (NSArray *)filerSpecialDB:(NSDictionary *)dbinfos atFilerNames:(NSArray *)dbname
{
    NSMutableArray *filters = [NSMutableArray array];
    
    NSArray *sdbs = [dbinfos objectForKey:dic_key_dbStaticList];
    if (sdbs.count > 0) {
        [filters addObjectsFromArray:sdbs];
    }
    NSArray *ddbs = [dbinfos objectForKey:dic_key_dbDynamicList];
    if (ddbs.count > 0) {
        [filters addObjectsFromArray:ddbs];
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.%@ IN %@",
                              dic_key_dbName,dbname];
    
    return [filters filteredArrayUsingPredicate:predicate];
}

/**
 *  移除数据库
 *
 *  @param dbpath 库的全路径
 */
- (void)todoRemoveDB:(NSURL *)dbpath
{
    NSError *error = nil;
    [[NSFileManager defaultManager]removeItemAtURL:dbpath error:&error];
    if (error) {
        NSLog(@"DataBaseManager Error : remove db error,reason : %@",error);
    }
}

/**
 *  数据库备分
 *
 *  @param dbpath src
 *
 *  @return 备分的path
 */
- (NSURL *)todoBackupDB:(NSURL *)dbpath
{
    NSString *path = [dbpath.path stringByDeletingLastPathComponent];
    
    if ([self fileExsistPath:path])
    {
        NSString *dbName = [dbpath.path lastPathComponent];
        NSString *bkpath = [NSString stringWithFormat:@"%@/bak_%@",path,dbName];
        NSURL *urlpath = [NSURL fileURLWithPath:bkpath];
        
        if ([[NSFileManager defaultManager]moveItemAtURL:dbpath toURL:urlpath error:nil])
        {
            return urlpath;
        }
    }

    return nil;
}

- (void)todoRestoreDB:(NSURL *)bkpath toSrc:(NSURL *)srcpath
{
    [[NSFileManager defaultManager]moveItemAtURL:bkpath toURL:srcpath error:nil];
}

- (NSInteger)todoUpdateDBs:(NSArray *)dbs
{
    NSString *defaultdbpath = [self getDefaultSetupDBPath];
    NSInteger totalfail = 0;
    for (NSDictionary *db in dbs)
    {
        @autoreleasepool {
            NSString *dbname = [db objectForKey:dic_key_dbName];
            NSString *dbversion = [db objectForKey:dic_key_dbVersion];
            //获取路径
            NSURL *setuppath = nil;
            //由委托来设置路径
            if ([self.delegate respondsToSelector:@selector(setupDbDirFromDBname:)])
            {
                setuppath = [self.delegate setupDbDirFromDBname:dbname];
            }
            if (!setuppath)
            {
                setuppath = [NSURL fileURLWithPath:[defaultdbpath stringByAppendingPathComponent:
                                                    [NSString stringWithFormat:@"%@%@",dbname,dbext]]];
            }
            
            if ([self fileExsistPath:setuppath.path])
            {
                //对已存在的进行版本比对
                NSDictionary *version = [self todoReadCurrentDbVersionInfo:setuppath.path];
                if (version) {
                    NSString *vs = [version objectForKey:@"VERSION"];
                    NSData *dbstruct = [version objectForKey:@"METADATA"];
                    
                    if (![dbversion isEqualToString:vs])
                    {   //对版本不同的进行处理，相同的则跳过吧
                        NSDictionary *olddb = [self jsonDataConvertToDictionary:dbstruct];
                        //进行简化处理
                        NSDictionary *newstruct = [self simpleDbStruct:db];
                        NSDictionary *oldstruct = [self simpleDbStruct:olddb];
                        
#ifdef DEBUG
                        NSLog(@"======================开始对库[%@]进行比较=====================",dbname);
#endif
                        NSDictionary *crtviewtriggers = [self todoReadCurrentDbViewsTriggers:setuppath.path];
                        //返回了比对完的信息
                        NSDictionary *newDBinfo = [self todoCompareDBStructWithOld:oldstruct
                                                                    andNewDBStruct:newstruct
                                                                  andViewsTriggers:crtviewtriggers];
#ifdef DEBUG
                        NSLog(@"开始构建[%@]升级语句",dbname);
#endif
                        NSMutableArray *sqls = (NSMutableArray *)[self todoMakeSQLForUpdateDB:newDBinfo];
                        if (sqls) {
                            //升级成功后更新到最新的版本库备分
                            Sqlstatement *st = [self makeVersionInfoStatmentByDB:db];
                            [sqls addObject:st];
                            
                            if ([self toCreateOrUpdateDBBySqls:sqls inPath:setuppath])
                            {
                                NSLog(@"数据库[%@]升级成功.",dbname);
                                [self todoFinishDelegateOrNotification:YES];
                            }
                            else
                            {
                                NSLog(@"数据库[%@]升级失败.",dbname);
                                totalfail++;
                                [self todoFinishDelegateOrNotification:NO];
                            }
                        }
                        else
                        {   //无任何sql执行。则认为Ok
                            NSLog(@"无任何更新,结束。");
                            [self todoFinishDelegateOrNotification:YES];
                        }
                    }
                    else
                    {
                        NSLog(@"库[%@]已是最新版本。",dbname);
                        [self todoFinishDelegateOrNotification:YES];
                    }
                }
                else
                {//无有版本号？则可能数据已损坏。则重新创建了
                    [self todoCreateDB:db inPath:setuppath];
                }
            }
            else
            {   //新增的
                [self todoCreateDB:db inPath:setuppath];
            }
        }
    }
    
    return ((totalfail == dbs.count) && (totalfail > 0)) ? allDBCreateFailed : (totalfail > 0) ? partDBCreateFailed : operationSuccess;;
}

/**
 *  读取当前app正在使用的数据库版本
 *
 *  @param dbpath 数据库路径
 *
 *  @return 版本字段信息
 */
- (NSDictionary *)todoReadCurrentDbVersionInfo:(NSString *)dbpath
{
    DBHelper *tmp = [self getThreadSafeDBHelperByDBPath:dbpath];
    NSArray * records = [tmp querysql:GET_VERSION_INFO];
    
    return records.count > 0 ? [records objectAtIndex:0] : nil;
}

/**
 *  读取当前库中的视图名称和触发器名称
 *
 *  @param dbpath
 *
 *  @return
 */
- (NSDictionary *)todoReadCurrentDbViewsTriggers:(NSString *)dbpath
{
    DBHelper *tmp = [self getThreadSafeDBHelperByDBPath:dbpath];
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSArray *records = [tmp querysql:SELECT_ALL_VIEWS_SQL];
    NSMutableArray *arr = [NSMutableArray array];
    for (NSDictionary *row in records) {
        [arr addObject:[row objectForKey:@"name"]];
    }
    
    if (arr.count > 0) {
        [result setObject:arr forKey:dic_key_current_views];
    }

    records = [tmp querysql:SELECT_ALL_TRIGGERS_SQL];
    arr = [NSMutableArray array];
    for (NSDictionary *row in records) {
        [arr addObject:[row objectForKey:@"name"]];
    }
    
    if (arr.count > 0) {
        [result setObject:arr forKey:dic_key_current_triggers];
    }
    
    return result.count > 0 ? result : nil;
}

/**
 *  比较库结构，返回需要在新版本处理的结构
 *
 *  @param oldstruct  经simpleDbStruct处理后得到
 *  @param newstruct  经simpleDbStruct处理后得到
 *  @param viewtriggers 从数据库读出来的当前所有视图和触发器名称
 *
 *  @return
 */
- (NSDictionary *)todoCompareDBStructWithOld:(NSDictionary *)oldstruct
                              andNewDBStruct:(NSDictionary *)newstruct
                            andViewsTriggers:(NSDictionary *)viewtriggers
{
#ifdef DEBUG
    double start = CFAbsoluteTimeGetCurrent();
#endif
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    //过滤出视图和触发器,索引
    NSArray *views_triggers = [NSArray arrayWithObjects:dic_key_dbViews,dic_key_dbTriggers,dic_key_dbIndexs, nil];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)",views_triggers];
    NSArray *tables = [[newstruct allKeys] filteredArrayUsingPredicate:predicate];
    NSArray *oldtables = [[oldstruct allKeys] filteredArrayUsingPredicate:predicate];
    
    //比较表,得到增，改，删信息
    NSDictionary *changetableinfo = [self todoCOmpareTablesOfKeys:tables
                                                        ofOldkeys:oldtables
                                                    withOldStruct:oldstruct
                                                     andNewStruct:newstruct];
    
    if (changetableinfo.count > 0) {
        [result addEntriesFromDictionary:changetableinfo];
    }

    NSDictionary *oindexs = [oldstruct objectForKey:dic_key_dbIndexs];
    NSDictionary *nindexs = [newstruct objectForKey:dic_key_dbIndexs];
    
    //比较索引(感觉没有删除了重建来得安全高效)
    NSDictionary *changeindexinfo = [self todoDropAndReCreateIndex:oindexs useNewIndexs:nindexs];
    //NSDictionary *changeindexinfo = [self todoCompareIndexs:oindexs withNewIndexs:nindexs];
    
    if (changeindexinfo.count > 0) {
        [result addEntriesFromDictionary:changeindexinfo];
    }
    
    //删除重键视图和触发器
    //直接删除所有视图和触发器，重新创建新的，以节省比较时间。
    NSArray *nviews = [newstruct objectForKey:dic_key_dbViews];
    //取到的是视图名称数组
    NSArray *oviews = [viewtriggers objectForKey:dic_key_current_views]; //[oldstruct objectForKey:dic_key_dbViews];
    
    if (nviews.count > 0) {
        [result setObject:nviews forKey:dic_key_createviews];
    }
    
    if (oviews.count > 0) {
        [result setObject:oviews forKey:dic_key_dropviews];
    }
    
    NSArray *ntriggers = [newstruct objectForKey:dic_key_dbTriggers];
    NSArray *otriggers = [viewtriggers objectForKey:dic_key_current_triggers];//[oldstruct objectForKey:dic_key_dbTriggers];
    
    if (otriggers.count > 0) {
        [result setObject:otriggers forKey:dic_key_droptriggers];
    }
    
    if (ntriggers.count > 0) {
        [result setObject:ntriggers forKey:dic_key_createviews];
    }
    
#ifdef DEBUG
    double end = CFAbsoluteTimeGetCurrent();
    NSLog(@"比较库完成。用时 : %f",end - start);
#endif
    
    return result.count > 0 ? result : nil;
}

//对字段进行排序
- (NSArray *)sortFields:(NSArray *)src
{
    return [src sortedArrayUsingComparator:
     ^NSComparisonResult(NSDictionary *fieldA, NSDictionary *fieldB) {
         //按字段名排序
         NSString *f1 = [fieldA objectForKey:dic_key_dbFieldName];
         NSString *f2 = [fieldB objectForKey:dic_key_dbFieldName];
         
         return [f1 compare:f2];
     }];
}

- (NSDictionary *)todoCOmpareTablesOfKeys:(NSArray *)tablenamekeys
                                ofOldkeys:(NSArray *)oldtablenamekeys
                            withOldStruct:(NSDictionary *)oldstruct
                             andNewStruct:(NSDictionary *)newstruct
{
#ifdef DEBUG
    double start = CFAbsoluteTimeGetCurrent();
#endif
    
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    //需要新增的表
    NSMutableDictionary *needcreatetables = [NSMutableDictionary dictionary];
    //需要修改的表(主要是字段结构发生变化)
    NSMutableDictionary *needaltertables = [NSMutableDictionary dictionary];
    //需要移除的表(可能升级后旧表被废弃掉了)
    NSMutableDictionary *needdeletetables = [NSMutableDictionary dictionary];
    //用于存放旧结构中的表在新结构中也存在
    NSMutableArray *exsistables = [NSMutableArray array];
    //过滤后只有表名，安心比对库中每个表是否有变化
    for (NSString *tablename in tablenamekeys)
    {
        if (![[oldstruct allKeys]containsObject:tablename])
        {//即旧版本中没有此表，说明是新增的
            //新增表(字典中已不存在索引的情况)
            [needcreatetables setObject:[newstruct objectForKey:tablename] forKey:tablename];
        }
        else
        {
            [exsistables addObject:tablename];
            //进行比较判断字段是否有变更
            NSArray *newfields = [newstruct objectForKey:tablename];
            NSArray *oldfields = [oldstruct objectForKey:tablename];
            
            //这段代码只是为了对某个表中相同的字段，结构只是改变某相字段的位置时，则不进行升级。
            oldfields = [self sortFields:oldfields];
            newfields = [self sortFields:newfields];
            
            NSString *a = [self serializationFieldsFromArray:oldfields];
            NSString *b = [self serializationFieldsFromArray:newfields];

            if ([[self sha1:a] hash] == [[self sha1:b] hash])
            {
                continue;
            }
            else
            {
                NSMutableArray *oldfieldnames = [NSMutableArray array];
                NSMutableArray *newfieldnames = [NSMutableArray array];
                
                for (NSDictionary * field in oldfields)
                {
                    NSString *fn = [field objectForKey:dic_key_dbFieldName];
                    [oldfieldnames addObject:fn];
                }
                
                for (NSDictionary * field in newfields)
                {
                    NSString *fn = [field objectForKey:dic_key_dbFieldName];
                    [newfieldnames addObject:fn];
                }
                
                //共同字段名称
                NSArray *common = [self getSameElement:oldfieldnames withB:newfieldnames];
                
                //说明需要进行升级表中的字段
                //提取新表旧表共有的字段名，用于做数据迁移

                NSDictionary *fielddic = [NSDictionary dictionaryWithObjectsAndKeys:common,
                                          dic_key_select_field,
                                          [newstruct objectForKey:tablename],
                                          dic_key_alter_field, nil];
                
                [needaltertables setObject:fielddic forKey:tablename];
            }
        }
    }
    
    //过滤出新版本中已移徐的表
    NSPredicate *filterpredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)",exsistables];
    NSArray *deletes = [oldtablenamekeys filteredArrayUsingPredicate:filterpredicate];
    
    for (NSString *deltablename in deletes)
    {
        [needdeletetables setObject:[oldstruct objectForKey:deltablename] forKey:deltablename];
    }
    
    if (needcreatetables.count > 0)
    {
        [results setValue:needcreatetables forKey:dic_key_createtables];
    }
    
    if (needaltertables.count > 0)
    {
        [results setValue:needaltertables forKey:dic_key_altertables];
    }
    
    if (needdeletetables.count > 0)
    {
        [results setValue:needdeletetables forKey:dic_key_droptables];
    }
    
#ifdef DEBUG
    double end = CFAbsoluteTimeGetCurrent();
    NSLog(@"比较库中表结构完成。用时 : %f",end - start);
#endif
    
    return results.count > 0 ? results : nil;
}


/**
 *  比较索引求出新增及删除的
 *
 *  @param oidxs
 *  @param nidxs
 *
 *  @return
 */
- (NSDictionary *)todoCompareIndexs:(NSDictionary *)oidxs withNewIndexs:(NSDictionary *)nidxs
{
#ifdef DEBUG
    double start = CFAbsoluteTimeGetCurrent();
#endif
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSMutableDictionary *crtidxs = [NSMutableDictionary dictionary];
    NSMutableDictionary *dpidxs = [NSMutableDictionary dictionary];
    
    if (oidxs.count > 0 && nidxs.count > 0) {
        //注意oidxs 和nidxs的字典中的key/value的顺序必须保存一至才能进行比较，否则是比不出来的
        NSUInteger oh = [self stringArrayOrDictionaryConvert2hashvalue:oidxs];
        NSUInteger nh = [self stringArrayOrDictionaryConvert2hashvalue:nidxs];
        if (oh != nh) {
            //获取共同存在indexname
            NSArray *oi = [oidxs allKeys];
            NSArray *ni = [nidxs allKeys];
            
            //取得交值
            NSArray *common = [self getSameElement:oi withB:ni];
            
            if (common.count > 0) {
                //需要删除的索引
                NSArray *dropidxs = [self getElements:oi notContains:common];
                //NSArray *createidxs = [self getElements:ni notContains:common];
                
                for (NSString *idxname in common)
                {
                    NSDictionary * o = [oidxs objectForKey:idxname];
                    NSDictionary * n = [nidxs objectForKey:idxname];
                    
                    NSUInteger oh = [self stringArrayOrDictionaryConvert2hashvalue:o];
                    NSUInteger nh = [self stringArrayOrDictionaryConvert2hashvalue:n];
                    if (oh != nh) {
                        //说明新表中该索引名对应的有可能已发现改变。因此此索引需要删除后重建
                        [dpidxs setObject:[oidxs objectForKey:idxname] forKey:idxname];
                    }
                }
                
                //新的全部重创建
                [crtidxs addEntriesFromDictionary:nidxs];
                
                for (NSString *dn in dropidxs)
                {
                    [dpidxs setObject:[oidxs objectForKey:dn] forKey:dn];
                }
            }
            else
            {   //无任何交值
                crtidxs = [NSMutableDictionary dictionaryWithDictionary:nidxs];
                dpidxs = [NSMutableDictionary dictionaryWithDictionary:oidxs];
            }
        }
    }
    else if (nidxs.count > 0)
    {
        //需要新建的索引
        crtidxs = [NSMutableDictionary dictionaryWithDictionary:nidxs];
    }
    else if (oidxs.count > 0)
    {
        //需要删除的索引
        dpidxs = [NSMutableDictionary dictionaryWithDictionary:oidxs];
    }
    
    if (crtidxs.count > 0) {
        [result setValue:crtidxs forKey:dic_key_createindexs];
    }
    
    if (dpidxs.count > 0) {
        [result setValue:crtidxs forKey:dic_key_dropindexs];
    }

#ifdef DEBUG
    double end = CFAbsoluteTimeGetCurrent();
    NSLog(@"比较库中索引完成。用时 : %f",end - start);
#endif
    
    return result.count > 0 ? result : nil;
}

/**
 *  直接删除了旧的索引，再来重建新的索引。一来是安全有保证，二来，不需要进行比对，效率应该比上面的比较方法更优
 *
 *  @param oldindexs
 *  @param newindexs
 *
 *  @return
 */
- (NSDictionary *)todoDropAndReCreateIndex:(NSDictionary *)oldindexs
                              useNewIndexs:(NSDictionary *)newindexs
{
#ifdef DEBUG
    double start = CFAbsoluteTimeGetCurrent();
#endif
 
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSMutableDictionary *crtidxs = [NSMutableDictionary dictionary];
    NSMutableDictionary *dpidxs = [NSMutableDictionary dictionary];
    
    crtidxs = [NSMutableDictionary dictionaryWithDictionary:newindexs];
    dpidxs = [NSMutableDictionary dictionaryWithDictionary:oldindexs];
    
    if (crtidxs.count > 0) {
        [result setValue:crtidxs forKey:dic_key_createindexs];
    }
    
    if (dpidxs.count > 0) {
        [result setValue:crtidxs forKey:dic_key_dropindexs];
    }
    
#ifdef DEBUG
    double end = CFAbsoluteTimeGetCurrent();
    
    NSLog(@"重建索引分析完成。用时 : %f",end - start);
#endif
    
    return result.count > 0 ? result : nil;
}

/**
 *  将从描述文件中读出的某一个数据库结构(结构中可能有多个库)转换为更利于比对的dic
 *
 *  @param dbstruct 一个库结构
 *
 *  @return 返回简化后的该库的结构信息，以便后面比对更为快速
 */
- (NSDictionary *)simpleDbStruct:(NSDictionary *)dbstruct
{
    //库中所有表结构，包括视图，触发器
    NSMutableDictionary *tables     = [NSMutableDictionary dictionary];
    NSMutableDictionary *indexs     = [NSMutableDictionary dictionary];
    
    //数据库所有表
    NSArray *tbs        = [dbstruct objectForKey:dic_key_dbTables];
    //数据库所有视图
    NSArray *vs         = [dbstruct objectForKey:dic_key_dbViews];
    //数据库所有触发器
    NSArray *tgs        = [dbstruct objectForKey:dic_key_dbTriggers];
    //数据库所有索引
    NSArray *idxs       = [dbstruct objectForKey:dic_key_dbIndexs];
    
    for (NSDictionary *itemtab in tbs)
    {
        //取得表名
        NSString *tabname = [itemtab objectForKey:dic_key_dbTableName];
        NSArray *fields  = [itemtab objectForKey:dic_key_dbFields];
        
        if (fields.count > 0) {
            [tables setObject:fields forKey:tabname];
        }
    }
    
    for (NSDictionary *idx in idxs)
    {
        NSString *indexname = [idx objectForKey:dic_key_dbFieldIndexName];
        [indexs setObject:idx forKeyedSubscript:indexname];
    }
    //添加索引
    if (indexs.count > 0) {
        [tables setObject:indexs forKeyedSubscript:dic_key_dbIndexs];
    }
    
    //检查视图
    if (vs.count > 0) {
        [tables setObject:vs forKey:dic_key_dbViews];
    }
    
    //检查触发器
    if (tgs.count > 0) {
        [tables setObject:tgs forKey:dic_key_dbTriggers];
    }
    
    return tables.count > 0 ? tables : nil;
}

/**
 *  生成版本升级语句
 *
 *  @param simpledbinfo
 *
 *  @return
 */
- (NSArray *)todoMakeSQLForUpdateDB:(NSDictionary *)simpledbinfo
{
    //必须按顺序处理
    /*
     1.删除新版本中不使用的表,然后创建或更新表。
     2.删除旧索引,然后重建新索引
     3.删除旧视图,然后重建新视图
     4.删除旧触发器,然后重建新触发器
     */
    NSMutableArray *result = [NSMutableArray array];
    NSString *sql = nil;
    
    //删除多余表
    NSDictionary *deltables = [simpledbinfo objectForKey:dic_key_droptables];
    for (NSString *tablename in [deltables allKeys])
    {
        sql = [NSString stringWithFormat:DROP_TABLE_SQL,tablename];
        [result addObject:sql];
    }
    
    //创建新增表
    NSDictionary *createtables = [simpledbinfo objectForKey:dic_key_createtables];
    for (NSString *tablename in [createtables allKeys])
    {
        NSArray  *fieldsinfo        = [createtables objectForKey:tablename];
        NSString *fields            = [self serializationFieldsFromArray:fieldsinfo];
        sql = [NSString stringWithFormat:CREATE_TABLE_FMT_SQL,tablename,fields];
        
        [result addObject:sql];
    }
    //更新字段变化表
    /*
     当表中有数据时
     将表名改为临时表
     ALTER TABLE MyTable RENAME TO _temp_MyTable;
     创建新表
     CREATE TABLE MyTable (....);
     导入数据
     INSERT INTO MyTable SELECT .., .. ,“用空来补充原来不存在的数据”  FROM _temp_MyTable;
     删除临时表
     DROP TABLE _temp_MyTable;
     */
    NSDictionary *alterstables = [simpledbinfo objectForKey:dic_key_altertables];
    for (NSString *tablename in [alterstables allKeys])
    {
        NSString *upcaseTablename = [tablename uppercaseString];
        //改为监时表
        NSString *tmp = [NSString stringWithFormat:@"_TEMP_%@",upcaseTablename];
        sql = [NSString stringWithFormat:RENAME_TABLENAME_SQL,upcaseTablename,tmp];
        [result addObject:sql];
        
        //创建新表
        NSDictionary *fieldinfo = [alterstables objectForKey:tablename];//此键值大小写敏感
        NSArray *newfields = [fieldinfo objectForKey:dic_key_alter_field];
        NSString *fields   = [self serializationFieldsFromArray:newfields];
        sql = [NSString stringWithFormat:CREATE_TABLE_FMT_SQL,upcaseTablename,fields];
        [result addObject:sql];
       
        //导入数据
        NSArray *select = [fieldinfo objectForKey:dic_key_select_field];
        if (select.count > 0) {
            NSString *fs = [select componentsJoinedByString:@","];
            sql = [NSString stringWithFormat:EXPORT_DATA_DEST_TABLE,upcaseTablename,fs,fs,tmp];
            [result addObject:sql];
        }
        
        //删除监时表
        sql = [NSString stringWithFormat:DROP_TABLE_SQL,tmp];
        [result addObject:sql];
    }
    
    //删除旧索引,然后重建新索引
    NSDictionary *delindexs = [simpledbinfo objectForKey:dic_key_dropindexs];
    NSDictionary *cindexs = [simpledbinfo objectForKey:dic_key_createindexs];
    
    for (NSString *delidxname in [delindexs allKeys])
    {
        sql = [NSString stringWithFormat:DROP_INDEX_SQL,delidxname];
        [result addObject:sql];
    }
    
    for (NSString *cidxname in [cindexs allKeys])
    {
        NSDictionary *index = [cindexs objectForKey:cidxname];
        NSString *type = @"";
        //必填
        NSString *tablename = [index objectForKey:dic_key_dbTableName];
        NSString *indexname = [index objectForKey:dic_key_dbFieldIndexName];
        NSString *indexFieldname = [index objectForKey:dic_key_dbFieldName];
        //可选
        NSString *indextype = [index objectForKey:dic_key_dbFieldIndexType];
        if (indextype) {
            type = @"UNIQUE";
        }
        
        NSString *desc = [index objectForKey:dic_key_IndexColumnDESC];
        NSString *asc = [index objectForKey:dic_key_IndexColumnASC];
        
        NSMutableArray *ar = [NSMutableArray array];
        if (desc.length > 0) {
            desc = [NSString stringWithFormat:@"%@ DESC",desc];
            [ar addObject:desc];
        }
        
        if (asc.length > 0) {
            asc = [NSString stringWithFormat:@"%@ DESC",asc];
            [ar addObject:asc];
        }
        
        if (ar.count > 0) {
            indexFieldname = [ar componentsJoinedByString:@","];
        }
        
        sql = [NSString stringWithFormat:CREATE_INDEX_FMT_SQL,type,
                         indexname,tablename,indexFieldname];
        
        [result addObject:sql];
    }
    
    //删除旧视图,然后重建新视图
    NSArray *delviewnames = [simpledbinfo objectForKey:dic_key_dropviews];
    for (NSString *viewname in delviewnames) {
        sql = [NSString stringWithFormat:DROP_VIEW_SQL,viewname];
        [result addObject:sql];
    }
    
    //直接是视图sql语句
    NSArray *viewsqls = [simpledbinfo objectForKey:dic_key_createviews];
    if (viewsqls.count > 0) {
        [result addObjectsFromArray:viewsqls];
    }

    //删除旧触发器,然后重建新触发器
    NSArray *deltriggernames = [simpledbinfo objectForKey:dic_key_droptriggers];
    for (NSString *triggername in deltriggernames) {
        sql = [NSString stringWithFormat:DROP_TRIGGER_SQL,triggername];
        [result addObject:sql];
    }
    
    NSArray *triggersqls = [simpledbinfo objectForKey:dic_key_createtriggers];
    if (triggersqls.count > 0) {
        [result addObjectsFromArray:triggersqls];
    }
    
    return result.count > 0 ? result : nil;
}

- (BOOL)toCreateOrUpdateDBBySqls:(NSArray *)sqls inPath:(NSURL *)dbsetuppath
{
#ifdef DEBUG
    double start = CFAbsoluteTimeGetCurrent();
#endif
    
    DBHelper *tmp = [self getThreadSafeDBHelperByDBPath:dbsetuppath.path];
    BOOL ok = [tmp execsqls:sqls inTransaction:YES];
    
#ifdef DEBUG
    double end = CFAbsoluteTimeGetCurrent();
    NSLog(@"数据库升级完成。用时 : %f",end - start);
#endif
    return ok;
}

- (void)todoFinishDelegateOrNotification:(BOOL)success
{
    if ([self.delegate respondsToSelector:@selector(databaseCreateOrUpdateFinish:)]) {
        [self.delegate databaseCreateOrUpdateFinish:success];
    }
    
    NSDictionary *dic = @{@"RESULT":[NSNumber numberWithBool:success]};
    [[NSNotificationCenter defaultCenter]postNotificationName:ntf_name_createorupdate_compeleted
                                                       object:nil
                                                     userInfo:dic];
}

/***********************************end DatabaseTools**********************************/

/**
 *  解释dbdesc.plist描述表(该方法是全库比较的)
 *
 *  @param dbinfo 从描述表读出的dic
 *
 *  @return 将描述表转换为更易比对的dic
 */
//- (NSDictionary *)reBuildDBsdescinfo:(NSDictionary *)dbinfos
//{
//    NSMutableDictionary *result     = [NSMutableDictionary dictionary];
//
//    //读取库名
//    NSArray * sdbs = [dbinfos objectForKey:dic_key_dbStaticList];
//    NSArray * dydbs = [dbinfos objectForKey:dic_key_dbDynamicList];
//    
//    NSMutableArray *dbs = [NSMutableArray array];
//    
//    if (sdbs.count > 0) {
//        [dbs addObjectsFromArray:sdbs];
//    }
//    
//    if (dydbs.count > 0) {
//        [dbs addObjectsFromArray:dydbs];
//    }
//    
//    for (NSDictionary *item in dbs)
//    {
//        //数据库名称
//        NSString *dbname    = [item objectForKey:dic_key_dbName];
//        
//        NSDictionary *tables = [self simpleDbStruct:item];
//        
//        [result setObject:tables forKey:dbname];
//    }
//
//    return result;
//}


///**
// *  将描述文件plist的dic进行比对(全库比对)
// *
// *  @param olddb 旧的数据库结构信息
// *  @param newdb 新的数据库结构信息
// *
// *  @return 在新版本中需要变更的信息
// */
//- (NSDictionary *)compareDBInfo:(NSDictionary *)olddb withNewDbInfo:(NSDictionary *)newdb
//{
//    double start = CFAbsoluteTimeGetCurrent();
//    
//    //旧版本的库结构
//    NSDictionary *odbs = [self reBuildDBsdescinfo:olddb];
//    //新版本的库结构
//    NSDictionary *ndbs = [self reBuildDBsdescinfo:newdb];
//    //需要创建的库结构
//    NSMutableDictionary *needcreatedbs = [NSMutableDictionary dictionary];
//    //需要新增的表
//    NSMutableDictionary *needcreatetables = [NSMutableDictionary dictionary];
//    //需要修改的表(主要是字段结构发生变化)
//    NSMutableDictionary *needaltertables = [NSMutableDictionary dictionary];
//    //需要移除的表(可能升级后旧表被废弃掉了)
//    NSMutableDictionary *needdeletetables = [NSMutableDictionary dictionary];
//    
//    for (NSString *dbname in [ndbs allKeys])
//    {
//        if (![[odbs allKeys]containsObject:dbname])
//        {  //旧版本中没有的，则新增
//            //NSLog(@"新增一个数据库");
//            [needcreatedbs setObject:[ndbs objectForKey:dbname] forKey:dbname];
//        }
//        else
//        {
//            //比对库中的表是否有变化
//            NSDictionary *newtables = [ndbs objectForKey:dbname];
//            NSDictionary *oldtables = [odbs objectForKey:dbname];
//            
//            NSUInteger newhash = [self stringArrayOrDictionaryConvert2hashvalue:newtables];
//            NSUInteger oldhash = [self stringArrayOrDictionaryConvert2hashvalue:oldtables];
//            
//            if (newhash == oldhash)
//            {
//                //如果库没有变化，跳过
//                continue;
//            }
//            
//            NSMutableArray *exsisttablename = [NSMutableArray array];
//            
//            for (NSString *tablename in [newtables allKeys])
//            {
//                if ([tablename isEqualToString:dic_key_dbTriggers]) {
//                    
//                    NSLog(@"进行比较触发器");
//                    [exsisttablename addObject:tablename];
//                }
//                else if ([tablename isEqualToString:dic_key_dbViews]) {
//                    NSLog(@"进行视图比对");
//                    [exsisttablename addObject:tablename];
//                }
//                else if (![[oldtables allKeys]containsObject:tablename])
//                {
//                    //NSLog(@"需要新增一个表 %@ \n",tablename);
//                    
//                    //库名＋表名，组合，从而可知要修改的表是属于哪个库的
//                    NSString *comprisekey = [NSString stringWithFormat:@"%@%@%@",dbname,
//                                             conjoin,tablename];
//                    [needcreatetables setObject:[newtables objectForKey:tablename]
//                                         forKey:comprisekey];
//                }
//                else
//                {
//                    [exsisttablename addObject:tablename];
//                    
//                    NSArray *newfields = [newtables objectForKey:tablename];
//                    NSArray *oldfields = [oldtables objectForKey:tablename];
//                    
//                    NSUInteger nfds = [self stringArrayOrDictionaryConvert2hashvalue:newfields];
//                    NSUInteger ofds = [self stringArrayOrDictionaryConvert2hashvalue:oldfields];
//                    
//                    if (nfds == ofds)
//                    {
//                        continue;
//                    }
//                    else
//                    {
//                        //NSLog(@"需要修改表字段 表名 : %@",tablename);
//                        NSString *comprisekey = [NSString stringWithFormat:@"%@%@%@",dbname,
//                                                 conjoin,tablename];
//                        [needaltertables setObject:[newtables objectForKey:tablename]
//                                            forKey:comprisekey];
//                    }
//                }
//            }
//            
//            NSArray *oletablenames =  [oldtables allKeys];
//            
//            NSPredicate * filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)",exsisttablename];
//            
//            NSArray * filters = [oletablenames filteredArrayUsingPredicate:filterPredicate];
//            
//            if (filters.count > 0)
//            {
////                NSLog(@"新版本中需要删除的表");
////                NSLog(@"filter = %@",filters);
//                for (NSString *deltablename in filters)
//                {
//                    @autoreleasepool {
//                        NSString *comprisekey = [NSString stringWithFormat:@"%@%@%@",dbname,
//                                                 conjoin,deltablename];
//                        
//                        [needdeletetables setObject:[oldtables objectForKey:deltablename]
//                                             forKey:comprisekey];
//                    }
//                }
//            }
//        }
//    }
//    
//    double end = CFAbsoluteTimeGetCurrent();
//    
//    NSLog(@"数据库版本比对耗时 : %f",end - start);
//    
//    
//    NSMutableDictionary *result = [NSMutableDictionary dictionary];
//    
//    [result setObject:needcreatedbs forKey:@"CREATE_DB_KEY"];
//    [result setObject:needcreatetables forKey:@"CREATE_TABLE_KEY"];
//    [result setObject:needaltertables forKey:@"ALTER_TABLE_KEY"];
//    [result setObject:needdeletetables forKey:@"DROP_TABLE_KEY"];
//    
//    
//    return result;
//}
//
//
///**
// *  加载plist数据库结构文件
// *
// *  @param plistfilename
// */
//- (void)loadCurrentDBVersionInfo:(NSString *)plistfilename
//{
//    NSString *path = [[NSBundle mainBundle] pathForResource:
//                      plistfilename ofType:@"plist"];
//    NSDictionary * vinfo = [NSDictionary dictionaryWithContentsOfFile:path];
//    
//    if (vinfo) {
//        
//        NSString *currentversionname = vinfo[@"currentversionname"];
//        path = [[NSBundle mainBundle] pathForResource:
//                          currentversionname ofType:@"plist"];
//        
//
//        NSString *path1 = [[NSBundle mainBundle] pathForResource:
//                @"dbdesc1" ofType:@"plist"];
//        
//        NSDictionary * dbinfo = [NSDictionary dictionaryWithContentsOfFile:path];
//        NSDictionary * ndbinfo = [NSDictionary dictionaryWithContentsOfFile:path1];
//        
//        //进行比对
//        NSDictionary * compareresult = [self compareDBInfo:dbinfo withNewDbInfo:ndbinfo];
//
//    }
//    else
//    {
//        NSLog(@"数据库版本信息丢失。");
//    }
//}
//
//- (void)loadDbversioninfoPlistFile:(NSString *)plistfile
//{
//    //完整路径
//    NSString *path = [[NSBundle mainBundle] pathForResource:
//                      plistfile ofType:@"plist"];
//    if ([[NSFileManager defaultManager]fileExistsAtPath:path])
//    {
//        NSDictionary * vinfo = [NSDictionary dictionaryWithContentsOfFile:path];
//        if (vinfo) {
//            //读取最新的版本描术文件以便进行加载
//            NSString *currentversionname = vinfo[@"currentversionname"];
//            path = [[NSBundle mainBundle] pathForResource:
//                    currentversionname ofType:@"plist"];
//            if ([[NSFileManager defaultManager]fileExistsAtPath:path])
//            {
//                //当前数据库描述结构
//                NSDictionary * currentdbinfo = [NSDictionary dictionaryWithContentsOfFile:path];
//            }
//            else
//            {
//                NSLog(@"DataBaseManager ERROR : 数据库描述文件不存在,请检查.");
//            }
//        }
//        else
//        {
//            NSLog(@"DataBaseManager ERROR : 当前数据库版本信息损坏.");
//        }
//    }
//    else
//    {
//        NSLog(@"DataBaseManager ERROR : 加载数据库版本信息文件失败.");
//    }
//}

@end

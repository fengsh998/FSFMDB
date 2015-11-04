//
//  DataBaseTools.h
//  Qianbao
//
//  Created by fengsh on 21/3/15.
//  Copyright (c) 2015年 fengsh. All rights reserved.
//
/*
    针对不同的关系型数据库进行处理
    主要用来对数据库升级，数据迁移处理。
 
    通过 dbversioninfo.plist 来指定当前app运行的数据版本
    每变化一个数据库版本需要重新产生一个描述文件
    如dbdesc.plist 下一版本为 dbdesc2.plist
    这些plist文件的名称需要开发者手工维护。没有自动工具

    本工具类使用前请认真阅读以下细节点
 
    数据库描述文档样例,所有key必须按样例中的对应,大小写敏感
    该文件描述表考虑一个project中存在多个库的使用。同时满足有静态和动态库的设计
 
 StaticDBList   中的库表示可以静态创建的,即一开创建就知道存放库的位置。
 DynamicDBList  中的库表示延迟创建,即这里库可能是依懒某些条件才进行创建的库,比如登录后根据用户ID来产生存放路径的库
 
 FieldType 键中的值只允许如下值(请严格遵守)
 TEXT,REAL,INTEGER,BLOB,VARCHAR,FLOAT,DOUBLE,DATE,TIME,BOOLEAN,TIMESTAMP,BINARY
 
 FieldConstraint 键中的值只允许如下值(请严格遵守),多个时以逗号隔开(注:如果是自增则必定为主键),如不需要约束则可以删除此键
 PRIMARY KEY,AUTOINCREMENT ,NOT NULL,UNIQUE,DEFAULT 1
 
 FieldIndexType 键中的值只允许如下值(请严格遵守)
 UNIQUE 或去除此键值的定义，去除后将默认创建普通索引，而不是唯一索引
 
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>StaticDBList</key>
<array>
<dict>
<key>DBTriggers</key>
<array>
<string>触发器语句</string>
</array>
<key>DBViews</key>
<array>
<string>视图语句</string>
</array>
<key>DBIndexs</key>
<array>
<dict>
<key>ColumnDESC</key>
<string>可指定多个降序字段以逗号隔开(a,b)-可选字段</string>
<key>ColumnASC</key>
<string>可指定多个升序字段以逗号隔开(c,d,e)-可选字段</string>
<key>DBTableName</key>
<string>对指定的表 必填</string>
<key>FieldName</key>
<string>指定的字段进行创建索引与表中的字段名对应(多个字段以逗号隔开) 必填</string>
<key>FieldIndexType</key>
<string>唯一 -可选字段</string>
<key>FieldIndexName</key>
<string>索引名 必填</string>
</dict>
</array>
<key>DBTables</key>
<array>
<dict>
<key>DBFields</key>
<array>
<dict>
<key>FieldConstraint</key>
<string>(唯一，允许为空，主键，自增，默认，外键)</string>
<key>FieldType</key>
<string>字段类型</string>
<key>FieldName</key>
<string>字段名</string>
</dict>
<dict>
<key>FieldConstraint</key>
<string>(唯一，允许为空，主键，自增，默认，外键)</string>
<key>FieldType</key>
<string>字段类型</string>
<key>FieldName</key>
<string>字段名</string>
</dict>
</array>
<key>DBTableName</key>
<string>表名</string>
</dict>
</array>
<key>DBVersion</key>
<string>1.0</string>
<key>DBName</key>
<string>库名称</string>
</dict>
</array>
<key>DynamicDBList</key>
<array>
<dict>
<key>DBTables</key>
<array>
<dict>
<key>DBFields</key>
<array>
<dict>
<key>FieldConstraint</key>
<string>(唯一，允许为空，主键，自增，默认，外键)</string>
<key>FieldType</key>
<string>字段类型</string>
<key>FieldName</key>
<string>字段名</string>
</dict>
<dict>
<key>FieldConstraint</key>
<string>(唯一，允许为空，主键，自增，默认，外键)</string>
<key>FieldType</key>
<string>字段类型</string>
<key>FieldName</key>
<string>字段名</string>
</dict>
</array>
<key>DBTableName</key>
<string>表名</string>
</dict>
</array>
<key>DBVersion</key>
<string>1.0</string>
<key>DBName</key>
<string>库名称</string>
</dict>
</array>
</dict>
</plist>
*/


#import <Foundation/Foundation.h>

//库列表
extern NSString * dic_key_dbStaticList;
extern NSString * dic_key_dbDynamicList;
//库名
extern NSString * dic_key_dbName;
//库的版本号
extern NSString * dic_key_dbVersion;
//表列表
extern NSString * dic_key_dbTables;
//视图列表
extern NSString * dic_key_dbViews;
//触发器列表
extern NSString * dic_key_dbTriggers;
//表名
extern NSString * dic_key_dbTableName;
//字段列表
extern NSString * dic_key_dbFields;
//字段名
extern NSString * dic_key_dbFieldName;
//字段类型
extern NSString * dic_key_dbFieldType;
//字段约束
extern NSString * dic_key_dbFieldConstraint;
//索引
extern NSString * dic_key_dbIndexs;
//字段索引名
extern NSString * dic_key_dbFieldIndexName;
//字段索引类型
extern NSString * dic_key_dbFieldIndexType;
extern NSString * dic_key_IndexColumnDESC;
extern NSString * dic_key_IndexColumnASC;


//通知
extern NSString * ntf_name_createorupdate_compeleted;



@protocol DataBaseToolsDelegate <NSObject>
@required
/**
 *  根据DB库名来委托处理最后决定产生DB存放路径,如果不设置委托，默认创建在~/documents下
 *
 *  @param dbname
 *
 *  @return 返回sqlite文件全路径(路径必须是创建好的)
 */
- (NSURL *)setupDbDirFromDBname:(NSString *)dbname;

@optional
/**
 *  数据库升级或创建完成。
 *
 *  @param success YES成功 NO失败
 */
- (void)databaseCreateOrUpdateFinish:(BOOL)success;

@end

/***************************************数据库管理类***********************************************/
typedef NS_ENUM(NSInteger, DBLoadType) {
    dbloadtypeStaticDB              = 0x01,   //数据库加载类型默认为静态无依赖的数据库
    dbloadtypeDynamicDB,                      //创建延迟加载的数据库
    dbloadtypeAllDB                           //如果条件满足时，可一次性加载静态和动态数据库(比如有历史账号的情况下)
};

typedef NS_ENUM(NSInteger, DBCreateMode)
{
    createmodeDefault               = 0x01,         //如果创建过了，则重新创建时如果DB存在则跳过
    createmodeUpdateWhenExsistDB    = 0x01 << 1,    /*(推荐)如果创建过程中发现在有更新时，则自动进行库升级，
                                                    如有某个表的字段增删改,库升级不影响原数据
                                                     */
    createmodeForceCreateDB         = 0x01 << 2,    //强重将原来的库删除，重新产生新的库，因此库中的数据将会丢失
};


@interface DataBaseTools : NSObject

@property (nonatomic,assign) id<DataBaseToolsDelegate> delegate;

+ (DataBaseTools *)defaultTools;

- (NSString *)getDefaultSetupDBPath;
/**
 *  测试用，后续移除
 */
- (void)setup;
/**
 *  解释数据库描述文件
 *
 *  @param filepath 描述文件的路径(文件为plist文件)
 *
 *  @return 生成的Dic数据
 */
- (NSDictionary *)parseDBDescriptionFile:(NSString *)filepath;
/**
 *  @param pliststructdata 必须是从plist文件中读取的
 *
 *  @return
 */
- (NSDictionary *)parseDBDescriptionData:(NSData *)pliststructdata;

/**
 *  通描述文件来创建数据库(只创建不进行数据对比)
 *
 *  @param plistfile dbdesc.plist文件
 */
- (NSInteger)CreateDBByDescriptionFile:(NSString *)plistfile withLoadType:(DBLoadType)loadtype;
- (NSInteger)CreateDBByDescriptionData:(NSData *)plistdata withLoadType:(DBLoadType)loadtype;

/**
 *  根据模式进行创建库
 *
 *  @param plistfile  库描述文件,plist
 *  @param loadtype
 *  @param createmode   createmodeDefault 对已存在的库，则在创建时直接跳过处理。
                        createmodeUpdateWhenExsistDB 当在创建库时,发现库结构有变化。就会进行更新操作
                        createmodeForceCreateDB 删除重键
 */
- (NSInteger)CreateOrUpdateDBByDescriptionFile:(NSString *)plistfile useLoadType:(DBLoadType)loadtype
                                 withMode:(DBCreateMode)createmode;
- (NSInteger)CreateOrUpdateDBByDescriptionData:(NSData *)plistdata useLoadType:(DBLoadType)loadtype
                                 withMode:(DBCreateMode)createmode;

/**
 *  特别指定只创建或升级dbname，库结构在plistfile中详细定义
 *
 *  @param plistfile  必须含有dbname的库结构信息
 *  @param dbname     指定创建或更新的数据库
 *  @param createmode 创建模式
 */
- (NSInteger)CreateOrUpdateSpecialDBFromDescriptionFile:(NSString *)plistfile withDBName:(NSString *)dbname
                                          withMode:(DBCreateMode)createmode;
- (NSInteger)CreateOrUpdateSpecialDBFromDescriptionData:(NSData *)plistdata withDBName:(NSString *)dbname
                                          withMode:(DBCreateMode)createmode;


@end

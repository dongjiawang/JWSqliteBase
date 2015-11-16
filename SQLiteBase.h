//
//  SQLiteBase.h
//  mySqlite
//
//  Created by henry on 15/11/16.
//  Copyright © 2015年 dongjiawang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface SQLiteBase : NSObject
//数据库密码
@property (nonatomic, strong) NSString *DB_PassWord;
@property (nonatomic) sqlite3 *sql_base;
//是否打开了数据库
@property (nonatomic, assign) BOOL DB_Open;
//具体的数据表名
@property (nonatomic, strong) NSString *myTableName;
//表记录，记录表的信息
@property (nonatomic, strong) NSMutableArray *myTableInfo;
@property (nonatomic, assign) BOOL hasUser;
//是否存在这个表
+(BOOL) isExistTable:(NSString *)tableName;

//根据一个表类型，生成一个表对象，是否需要用户名
+(id)GetTableDBWithTableName:(NSString *)tableName hasUser:(BOOL)has;
//给一个已知的表添加字段
+(BOOL)addColumToTable:(NSString *)tableName FileName:(NSString *)file FileType:(NSString *)fileType;

#pragma mark 私有方法
#pragma mark -
//根据参数创建表，keys是主键，needs是非主键，非主键是必要的，假如需要排序、搜索等功能，data是数据
-(BOOL)CreateTableWithKeys:(NSArray *)keys OtherNeeds:(NSArray *)needs Data:(NSString *)data;

//向表中插入数据，一个dict是一条记录，如果存在记录，是否覆盖
-(BOOL)InsertDataWithDict:(NSDictionary *)dict Replace:(BOOL)replace;

//更新表字段，key是需要更新的字段名称，newValue是更新后的值，where是条件（sql语句），condition是满足更新的条件，use是否使用用户名为条件
-(BOOL)UpdateRecordWithKey:(NSString *)key Value:(NSString *)newValue Where:(NSString *)where Condition:(NSString *)condition UseUser:(BOOL)use;

//获取表中的前N项数据，begin是开始行号，Rows是返回多少行，key是按照哪个字段排序，样式为nil或者『key1 desc 』，key与values的个数必须相等，use是否使用用户名作为条件，，为了匹配模糊查询，此处的values前面必须加上=，like等关键字
-(NSMutableArray *)GetRowsWithBegin:(NSUInteger)begin Rows:(NSUInteger)rows OrderBy:(NSString *)key Keys:(NSArray *)keys Values:(NSArray *)values UseUser:(BOOL)use;

//从数据库中拿到所有数据，用户名为条件
-(NSMutableArray *)GetAllRecordsUseUser:(BOOL)use;

//从数据库中获取某个key的所有数据，用户名为条件
-(NSMutableArray *)GetAllRecordsWithKeys:(NSArray *)keys Values:(NSArray *)values UseUser:(BOOL)use;

//根据关键字和关键字的值得到一条数据记录，如果不存在返回nil，也可以用来判断是否存在某条记录，keys与values的个数必须相等，use是否使用用户名为条件
-(NSMutableArray *)GetOneRecordWithKeys:(NSArray *)keys Values:(NSArray *)values UseUser:(BOOL)use;

//删除所有数据，使用用户名为条件
-(BOOL)DeleteAllRecordsUseUser:(BOOL)use;

//删除单条数据，keys是对应关键字，values关键字的值,是否使用用户名为条件
-(BOOL)DeleteOneRecordWithKeys:(NSArray *)keys Values:(NSArray *)values UseUser:(BOOL)use;

//根据SQL语句得到值
-(NSMutableArray *)GetRecordsWithSql:(NSString *)sql;

#pragma mark 类公共方法
#pragma mark -
//创建数据库
+(void)CreateDB;

//打开数据库
+(BOOL)OpenDB;

//关闭数据库
+(BOOL)closeDB;

//使用sql语句创建表
+(BOOL)CreateTableWithSql:(NSString *)sql;

//使用sql语句删除表
+(BOOL)DeleteTableWithSql:(NSString *)sql;

//使用sql语句更新表
+(BOOL)UpdateTableWithSql:(NSString *)sql;

//使用sql判断是否存在表
+(BOOL)isExistTableWithSql:(NSString *)sql;

//使用sql语句查询需要的数据
+(NSMutableArray *)GetNeedRecordWithSql:(NSString *)sql;

@end

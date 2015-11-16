//
//  SQLiteBase.m
//  mySqlite
//
//  Created by henry on 15/11/16.
//  Copyright © 2015年 dongjiawang. All rights reserved.
//

#import "SQLiteBase.h"
#import <Foundation/Foundation.h>

#define MyDB_Version 1

@implementation SQLiteBase

+(SQLiteBase *)GetInstance {
    static SQLiteBase *sqliteBase = nil;
    if (sqliteBase == nil) {
        sqliteBase.DB_Open = NO;
        sqliteBase.sql_base = nil;
        sqliteBase.DB_PassWord = @"myPassword";
    }
    return sqliteBase;
}

sqlite3 *ppDb = nil;

//把字典写入文件
+(void) WriteDicToFile:(NSDictionary *)dic FileName:(NSString *)file
{
    NSArray *paths=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *path=[paths    objectAtIndex:0];
    NSString *filename=[path stringByAppendingPathComponent:file];
    [dic writeToFile:filename  atomically:YES];
}

//解析文件得到字典，数据表的信息
+(NSDictionary *)ParseDicFromFile:(NSString *)file {
    //	读操作
    NSArray *paths=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *path=[paths    objectAtIndex:0];
    NSString *filename=[path stringByAppendingPathComponent:file];
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithContentsOfFile:filename];
    return dic;
}

+(BOOL)isExistTable:(NSString *)tableName {
#if 1
    if (![SQLiteBase OpenDB]) {
        return NO;
    }
    sqlite3_stmt *statement = nil;
    
    NSString *sql= [NSString stringWithFormat:@"SELECT count(*) FROM sqlite_master WHERE type='table' AND name='%@',tableName"];
    const char *cSql = [sql UTF8String];
    //验证sql语句是否成功
    if (sqlite3_prepare_v2(ppDb, cSql, -1, &statement, NULL) != SQLITE_OK)
    {
        return NO;
    }
    int success = sqlite3_step(statement);
    // 释放资源
    sqlite3_finalize(statement);
    if (success != SQLITE_DONE)
    {
        return NO;
    }
    
    return YES;
    
#else
    NSDictionary *dict = [SQLiteBase ParseDicFromFile:tableName];//通过本地plist文件判断表结构
    if (dict != nil) {
        if ([dict objectForKey:tableName]) {
            return YES;//存在
        }else{
            return NO;//不存在
        }
    }else{
        return NO;
    }
#endif
}

+(id)GetTableDBWithTableName:(NSString *)tableName hasUser:(BOOL)has {
    if (![SQLiteBase OpenDB]) {
        return nil;
    }
    SQLiteBase *table = [[SQLiteBase alloc] init];
    table.myTableName = tableName;
    table.hasUser = has;
    NSDictionary *dict = [SQLiteBase ParseDicFromFile:tableName];
    if (dict) {
        table.myTableInfo = [dict objectForKey:tableName];
    }
    return table;
}

+(BOOL)addColumToTable:(NSString *)tableName FileName:(NSString *)file FileType:(NSString *)fileType {
    if (![SQLiteBase OpenDB]) {
        return NO;
    }
    sqlite3_stmt *statement = nil;
    NSString *sql = [NSString stringWithFormat:@"alter table '%@' add column '%@' %@",tableName,file,fileType];
    const char *cSql = [sql UTF8String];
    const char *key = [[SQLiteBase GetInstance].DB_PassWord UTF8String];
    sqlite3_key(ppDb, key, strlen(key));
    
    if (sqlite3_prepare_v2(ppDb, cSql, -1, &statement, NULL) != SQLITE_OK) {
        return NO;
    }
    int success = sqlite3_step(statement);
    // 释放资源
    sqlite3_finalize(statement);
    if (success != SQLITE_DONE)
    {
        NSLog(@"添加字段失败，表名为%@", tableName);
        return NO;
    }
    NSDictionary *dic = [SQLiteBase ParseDicFromFile:@"dbInfo.plist"];
    
    if (dic != nil)
    {
        NSMutableArray *tArr = [dic objectForKey:tableName];
        
        [tArr addObject:[NSDictionary dictionaryWithObjectsAndKeys:fileType,@"type",file,@"key", nil]];
        
        [SQLiteBase WriteDicToFile:dic FileName:@"dbInfo.plist"];
    }
    
    return YES;
}

#pragma mark 私有方法
#pragma mark -
-(BOOL)CreateTableWithKeys:(NSArray *)keys OtherNeeds:(NSArray *)needs Data:(NSString *)data {
     //如果有信息，说明注册成功了已经
    if (self.myTableInfo) {
        return YES;
    }
    //首先确保数据库是打开的
    if (![SQLiteBase OpenDB]) {
        return NO;
    }
    //把所有非数据的字段写入一个数组中
    NSMutableArray *allArr = [NSMutableArray arrayWithCapacity:10];
    if ([keys count] > 0) {
        [allArr addObjectsFromArray:keys];
    }
    if ([needs count] > 0) {
        [allArr addObjectsFromArray:needs];
    }
    if (self.hasUser) {
        [allArr insertObject:@"userName" atIndex:0];
    }
    
    NSUInteger allCount = [allArr count];
    if (self.myTableInfo == nil) {
        self.myTableInfo = [NSMutableArray arrayWithCapacity:allCount+1];
    }
    //插入数据
    for (int i = 0; i < allCount; ++i) {
        NSString *key = [allArr objectAtIndex:i];//记录表结构
        [self.myTableInfo addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"text",@"type", key,@"key", nil]];
    }
    
    //创建sql语句
    NSMutableString *cSql = [NSMutableString stringWithFormat:@"create table if not exists %@ (",self.myTableName];
    //把非数据类型的字段加入sql语句
    
    for(NSString *key in allArr)
    {
        [cSql appendFormat:@"%@ text,",key];
    }
    
    //把数据类型的字段加入Sql语句
    if (data != nil)
    {
        [cSql appendFormat:@"%@ blob,",data];
        [self.myTableInfo addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"blob",@"type", data,@"key", nil]];
    }
    //添加主键
    [cSql appendString:@"primary key("];
    
    int keyCount = [keys count];
    if (keyCount > 0)//有多个主键的情况
    {
        for(int i = 0; i < keyCount - 1; ++i)
        {
            NSString *key = [keys objectAtIndex:i];
            [cSql appendFormat:@"%@,",key];
        }
        
        if(self.hasUser)
        {
            [cSql appendString:@"userName,"];
        }
        [cSql appendFormat:@"%@)",[keys objectAtIndex:keyCount - 1]];
    }
    else
    {
        if(self.hasUser)
        {
            [cSql appendString:@"userName)"];
        }
    }
    
    [cSql appendString:@")"];
    
        NSMutableDictionary *dic = (NSMutableDictionary *)[SQLiteBase ParseDicFromFile:@"dbInfo.plist"];
        if (dic == nil)
        {
            dic = [NSMutableDictionary dictionaryWithCapacity:1];
        }
        [dic setObject:self.myTableInfo forKey:self.myTableName];
        [SQLiteBase WriteDicToFile:dic FileName:@"dbInfo.plist"];
    
    return [SQLiteBase CreateTableWithSql:cSql];
}

-(BOOL)InsertDataWithDict:(NSDictionary *)dict Replace:(BOOL)replace {
    //打开数据库
    if (!self.DB_Open) {
        if(![SQLiteBase OpenDB])
        {
            return NO;
        }
    }
    NSMutableDictionary *tmpDict = [NSMutableDictionary dictionaryWithDictionary:dict];
    if (self.hasUser) {
        //这里的userName可以换成自己存储的全局的userName
        [tmpDict setObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"userName"] forKey:@"userName"];
    }
    NSMutableArray *allKeys = [NSMutableArray arrayWithArray:[tmpDict allKeys]];
    NSMutableString *cSql = nil;
    
    //生成插入语句
    if (replace) {
        cSql = [NSMutableString stringWithFormat:@"insert or REPLACE into %@(",self.myTableName];
    }else {
        cSql = [NSMutableString stringWithFormat:@"insert into %@(",self.myTableName];
    }
    NSUInteger keysCount = [allKeys count];
    if (keysCount > 0) {
        for (int i = 0; i < keysCount; ++i) {
            [cSql appendFormat:@"%@,",[allKeys objectAtIndex:i]];
        }
        [cSql appendFormat:@"%@)",[allKeys objectAtIndex:keysCount -1]];
    }else {
        return NO;
    }
    
    [cSql appendString:@" values("];
    
    
    for(int i = 0; i<keysCount -1; ++i)
    {
        [cSql appendString:@"?,"];
    }
    [cSql appendString:@"?)"];
    
    
    //测试sql 语句是否正确
    sqlite3_stmt *statement;
    
    const char *insertStatement = [cSql UTF8String];
    //验证sql语句是否成功
    const char *key = [[SQLiteBase GetInstance].DB_PassWord UTF8String];
    sqlite3_key(ppDb, key, strlen(key));

    if(sqlite3_prepare_v2(ppDb, insertStatement, -1, &statement, NULL) != SQLITE_OK)
    {
        NSLog(@"向表格中插入数据失败,可能Sql语句不正确，表名为%@", self.myTableName);
        return  NO;
    }
    
    for(int i = 0; i < keysCount;++i)
    {
        NSString *key = [allKeys objectAtIndex:i];
        
        id value = [tmpDict objectForKey:key];
        
        //如果是Data类型
        if ([value isKindOfClass:[NSData class]])
        {
            sqlite3_bind_blob(statement,  i+1, [value bytes], [value length], NULL);
        }
        else//是字符串类型
        {
            sqlite3_bind_text(statement, i+1, [value UTF8String], -1, NULL);
        }
    }
    
    int success = sqlite3_step(statement);
    // 释放资源
    sqlite3_finalize(statement);
    
    if (success == SQLITE_ERROR)
    {
        NSLog(@"向表格中插入数据失败,未知原因提前结束，表名为%@", self.myTableName);
        return NO;
    }

    //插入成功
    return YES;
}

-(BOOL)UpdateRecordWithKey:(NSString *)key Value:(NSString *)newValue Where:(NSString *)where Condition:(NSString *)condition UseUser:(BOOL)use {
    if (![SQLiteBase OpenDB]) {
        return NO;
    }
    @try {
        NSString *tmpUpdateSql = nil;
        if (use && self.hasUser) {
           tmpUpdateSql =  [NSString stringWithFormat:@"UPDATE %@ SET %@ = ? where %@ = ? and userName = ?",self.myTableName,key,where];
        }else {
           tmpUpdateSql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = ? where %@ = ?",self.myTableName,key,where];//@"UPDATE tb_bulletlist SET has_read = ? where bulletin_code = ? and user_name=?";
        }
        sqlite3_stmt *statement;
        //验证SQL语句
        const char *key = [[SQLiteBase GetInstance].DB_PassWord UTF8String];
        sqlite3_key(ppDb, key, strlen(key));
        if(sqlite3_prepare_v2(ppDb, [tmpUpdateSql UTF8String], -1, &statement, nil) != SQLITE_OK)
        {
            NSLog(@"更新数据失败，表名为%@",self.myTableName);
            return  NO;
        }
        sqlite3_bind_text(statement, 1, [newValue UTF8String], -1, NULL);
        sqlite3_bind_text(statement, 2, [condition UTF8String], -1, NULL);

        if (use && self.hasUser) {
            sqlite3_bind_text(statement, 3, [[[NSUserDefaults standardUserDefaults] objectForKey:@"userName"] UTF8String], -1, NULL);
        }
        int success = sqlite3_step(statement);
        
        sqlite3_finalize(statement);
        if (success != SQLITE_DONE)
        {
            NSLog(@"更新数据失败,未知原因提前结束，表名为%@", self.myTableName);
            return NO;
        }
    }
    @catch (NSException *exception) {
        NSLog(@"%@", exception);
    }
    return YES;
}

-(NSMutableArray *)GetRowsWithBegin:(NSUInteger)begin Rows:(NSUInteger)rows OrderBy:(NSString *)key Keys:(NSArray *)keys Values:(NSArray *)values UseUser:(BOOL)use {
    
    if ([keys count] != [values count])
    {
        NSLog(@"GetRowsWithBegin 数据查询参数keys与values个数不一致，表名为%@",self.myTableName);
        return nil;
    }
    //打开数据库
    if (!self.DB_Open) {
        if (![SQLiteBase OpenDB]) {
            NSLog(@"查询数据失败,打开数据库出错！");
            return nil;
        }
    }
    
    NSMutableString *cSql = nil;
    
    if([keys count] > 0 || key != nil)
    {
        cSql = [NSMutableString stringWithFormat:@"select *from %@ where ",self.myTableName];
    }
    else
    {
        cSql = [NSMutableString stringWithFormat:@"select *from %@ ",self.myTableName];
    }
    
    if (use && self.hasUser)
    {
        if ([keys count] > 0)
        {
            [cSql appendFormat:@"userName = '%@' and ",[[NSUserDefaults standardUserDefaults] objectForKey:@"userName"]];
        }
        else
        {
            [cSql appendFormat:@"userName = '%@' ",[[NSUserDefaults standardUserDefaults] objectForKey:@"userName"]];
        }
    }
    
    int keyCount = [keys count];
    for (int i = 0; i < keyCount; ++i)
    {
        if (i == 0)
        {
            [cSql appendFormat:@"%@ %@",[keys objectAtIndex:i],[values objectAtIndex:i]];
        }
        else
        {
            [cSql appendFormat:@" and %@ %@",[keys objectAtIndex:i],[values objectAtIndex:i]];
        }
        
    }
    
    if (key != nil)
    {
        [cSql appendFormat:@"order by %@",key];
    }
    
    [cSql appendFormat:@" limit %d,%d",begin,rows];
    
    return [self GetRecordsWithSql:cSql];
}

-(NSMutableArray *)GetAllRecordsUseUser:(BOOL)use {
    
    // 打开数据库
    if (!self.DB_Open)
    {
        if(![SQLiteBase OpenDB])
        {
            NSLog(@"查询数据失败,打开数据库出错!");
            return nil;
        }
    }
    
    // 生成查询语句
    NSString *tmpSql = nil;
    if (use && self.hasUser)
    {
        tmpSql = [NSString stringWithFormat:@"select * from %@ where userName = '%@'",self.myTableName,[[NSUserDefaults standardUserDefaults] objectForKey:@"userName"]];
    }
    else
    {
        tmpSql = [NSString stringWithFormat:@"select * from %@",self.myTableName];
    }
    
    return [self GetRecordsWithSql:tmpSql];
}

-(NSMutableArray *)GetAllRecordsWithKeys:(NSArray *)keys Values:(NSArray *)values UseUser:(BOOL)use {
    if ([keys count] != [values count])
    {
        NSLog(@"GetAllRecordWithKeys 数据查询参数keys与values个数不一致，表名为%@", self.myTableName);
        return nil;
    }
    
    // 打开数据库
    if (!self.DB_Open)
    {
        if(![SQLiteBase OpenDB])
        {
            NSLog(@"查询数据失败,打开数据库出错!");
            return nil;
        }
    }
    
    NSMutableString *cSql = [NSMutableString stringWithFormat:@"select * from %@ where ",self.myTableName];
    if (use && self.hasUser)
    {
        [cSql appendFormat:@"userName = '%@' and ",[[NSUserDefaults standardUserDefaults] objectForKey:@"userName"]];
    }
    
    int keyCount = [keys count];
    for (int i = 0; i < keyCount; ++i)
    {
        if (i == 0)
        {
            [cSql appendFormat:@"%@ = '%@'",[keys objectAtIndex:i],[values objectAtIndex:i]];
        }
        else
        {
            [cSql appendFormat:@" and %@ = '%@'",[keys objectAtIndex:i],[values objectAtIndex:i]];
        }
        
    }
    
    return [self GetRecordsWithSql:cSql];
}

-(NSMutableArray *)GetOneRecordWithKeys:(NSArray *)keys Values:(NSArray *)values UseUser:(BOOL)use {
    if ([keys count] != [values count])
    {
        NSLog(@"GetOneRecordWithKeys 数据查询参数keys与values个数不一致，表名为%@", self.myTableName);
        return nil;
    }
    
    // 打开数据库
    if (!self.DB_Open)
    {
        if(![SQLiteBase OpenDB])
        {
            NSLog(@"查询数据失败,打开数据库出错!");
            return nil;
        }
    }
    
    NSMutableString *cSql = [NSMutableString stringWithFormat:@"select * from %@ where ",self.myTableName];
    if (use && self.hasUser)
    {
        [cSql appendFormat:@"userName = '%@' and ",[[NSUserDefaults standardUserDefaults] objectForKey:@"userName"]];
    }
    
    int keyCount = [keys count];
    for (int i = 0; i < keyCount; ++i)
    {
        if (i == 0)
        {
            [cSql appendFormat:@"%@ = '%@'",[keys objectAtIndex:i],[values objectAtIndex:i]];
        }
        else
        {
            [cSql appendFormat:@" and %@ = '%@'",[keys objectAtIndex:i],[values objectAtIndex:i]];
        }
        
    }
    
    NSArray *tmpArr = [self GetRecordsWithSql:cSql];
    
    if ([tmpArr count] == 0)
    {
        return nil;
    }
    else
    {
        return [tmpArr objectAtIndex:0];
    }
}

-(BOOL)DeleteAllRecordsUseUser:(BOOL)use {
    NSString*sql= nil;
    if (use && self.hasUser)
    {
        sql = [NSString stringWithFormat: @"DELETE FROM %@ WHERE userName='%@'",self.myTableName,[[NSUserDefaults standardUserDefaults] objectForKey:@"userName"]];
    }
    else
    {
        sql = [NSString stringWithFormat: @"DELETE FROM %@",self.myTableName];
    }
    
    return [SQLiteBase DeleteTableWithSql:sql];
}

-(BOOL)DeleteOneRecordWithKeys:(NSArray *)keys Values:(NSArray *)values UseUser:(BOOL)use {
    if ([keys count] != [values count])
    {
        NSLog(@"DeleteOneRecordWithKeys 数据查询参数keys与values个数不一致，表名为%@", self.myTableName);
        return NO;
    }
    
    // 打开数据库
    if (!self.DB_Open)
    {
        if(![SQLiteBase OpenDB])
        {
            NSLog(@"查询数据失败,打开数据库出错!");
            return NO;
        }
    }
    
    NSMutableString *cSql = [NSMutableString stringWithFormat:@"delete from %@ where ",self.myTableName];
    
    int count = [keys count];
 
        int i = 0;
        if (use)
        {
            for(; i < count; ++i)
            {
                NSString *key = [keys objectAtIndex:i];
                NSString *value = [values objectAtIndex:i];
                
                [cSql appendFormat:@"%@ = '%@' and ",key,value];
            }
            [cSql appendFormat:@"userName = '%@'",[[NSUserDefaults standardUserDefaults] objectForKey:@"userName"]];
        }
        else
        {
            for(; i < count-1; ++i)
            {
                NSString *key = [keys objectAtIndex:i];
                NSString *value = [values objectAtIndex:i];
                
                [cSql appendFormat:@"%@ = '%@' and ",key,value];
            }
            
            NSString *key = [keys objectAtIndex:i];
            NSString *value = [values objectAtIndex:i];
            [cSql appendFormat:@"%@ = '%@'",key,value];
        }
    
    return [SQLiteBase DeleteTableWithSql:cSql];
}

-(NSMutableArray *)GetRecordsWithSql:(NSString *)sql {
    @try
    {
        sqlite3_stmt *statement = nil;
        const char *tmpSql = [sql UTF8String];
        //验证sql语句是否成功
        const char *key = [[SQLiteBase GetInstance].DB_PassWord UTF8String];
        sqlite3_key(ppDb, key, strlen(key));
        if (sqlite3_prepare_v2(ppDb, tmpSql, -1, &statement, NULL) != SQLITE_OK)
        {
            NSLog(@"sql语句有问题，不能被执行，表名为%@", self.myTableName);
            return nil;
        }
        
        int count = [self.myTableInfo count];
        
        NSMutableArray *rowsArr = [[NSMutableArray alloc] initWithCapacity:10];
        
        // 获得结果集，把查询结果写入数组
        while(sqlite3_step(statement) == SQLITE_ROW)
        {
            NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:count];
            for (int i = 0; i < count; ++i)
            {
                NSDictionary *tmpdic = [self.myTableInfo objectAtIndex:i];
                NSString *dataType = [tmpdic objectForKey:@"type"];
                NSString *dkey = [tmpdic objectForKey:@"key"];
                
                if ([dataType isEqualToString:@"blob"])
                {
                    NSUInteger blobLength = sqlite3_column_bytes(statement, i);
                    NSData *data = [NSData dataWithBytes:sqlite3_column_blob(statement, i) length:blobLength];
                    
                    [dic setObject:data forKey:dkey];
                }
                else
                {
                    char *str = (char*)sqlite3_column_text(statement, i);
                    if (str != nil)
                    {
                        NSString *value = [NSString stringWithUTF8String:str];
                        [dic setObject:value forKey:dkey];
                    }
                    else
                    {
                        [dic setObject:@"" forKey:dkey];
                    }
                }
            }
            
            [rowsArr addObject:dic];
            
        }
        
        sqlite3_finalize(statement);
        
        if ([rowsArr count] < 1)
        {
            return nil;
        }
        return rowsArr;
    }
    @catch (NSException *e)
    {
        // LOG_CERR(e);
    }
}

#pragma mark 类公共方法
#pragma mark -
+(void)CreateDB {
    NSArray *pathArr = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docPaths = [pathArr objectAtIndex:0];
    NSString *dbPath = [docPaths stringByAppendingFormat:@"/myDB.db"];
    
    int status = sqlite3_open([dbPath UTF8String], &ppDb);
    
    if (status != SQLITE_OK)
    {
        NSLog(@"创建数据库出错!");
        return;
    }
    
    [SQLiteBase GetInstance].DB_Open  = YES;
}

+(BOOL)OpenDB {
    if ([SQLiteBase GetInstance].DB_Open) {
        return [SQLiteBase GetInstance].DB_Open;
    }
    //在文稿中创建数据库文件
    NSArray *pathArr = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docPaths = [pathArr objectAtIndex:0];
    NSString *dbPath = [docPaths stringByAppendingFormat:@"/myDB.db"];
    
    int status = sqlite3_open([dbPath UTF8String], &ppDb);
    if (status != SQLITE_OK) {
        [SQLiteBase GetInstance].DB_Open = NO;
        return [SQLiteBase GetInstance].DB_Open;
    }
    [SQLiteBase GetInstance].DB_Open = YES;
    NSUserDefaults *dbDefault = [NSUserDefaults standardUserDefaults];
    int db_version = [[dbDefault objectForKey:@"dbVersion"] intValue];
    if (MyDB_Version > db_version || db_version == 0) {
        //如果版本更新可以在这里对需要的表进行添加字段
        
        
        [dbDefault setInteger:MyDB_Version forKey:@"dbVersion"];
    }
    
    return [SQLiteBase GetInstance].DB_Open;
}

+(BOOL)closeDB {
    if ([SQLiteBase GetInstance].DB_Open)
    {
        int status = sqlite3_close(ppDb);
        if (status != SQLITE_OK)
        {
            NSLog(@"关闭数据库失败!");
            [SQLiteBase GetInstance].DB_Open = YES;
            return NO;
        }
    }
    [SQLiteBase GetInstance].DB_Open = NO;
    
    //关闭数据库成功
    
    return YES;
}

+(BOOL)CreateTableWithSql:(NSString *)sql {
    if (![SQLiteBase GetInstance].DB_Open)
    {
        if(![SQLiteBase OpenDB])
        {
            NSLog(@"创建表格失败,原因打开数据库出错！");
            return NO;
        }
    }
    
    sqlite3_stmt *statement;
    //验证sql语句是否成功
    const char *key = [[SQLiteBase GetInstance].DB_PassWord UTF8String];
    sqlite3_key(ppDb, key, strlen(key));
    if(sqlite3_prepare_v2(ppDb, [sql UTF8String], -1, &statement, nil) != SQLITE_OK)
    {
        NSLog(@"创建表格失败！");
        return  NO;
    }
    
    int success = sqlite3_step(statement);
    sqlite3_finalize(statement);
    if (success != SQLITE_DONE)
    {
        NSLog(@"在创建表格的过程中出错，创建没有进行完！");
        return NO;
    }
    
    return YES;
}

+(BOOL)DeleteTableWithSql:(NSString *)sql {

    if(![SQLiteBase OpenDB])
    {
        return NO;
    }
    @try
    {
        sqlite3_stmt *statement;
        //验证sql语句是否成功
        const char *key = [[SQLiteBase GetInstance].DB_PassWord UTF8String];
        sqlite3_key(ppDb, key, strlen(key));
        
        if(sqlite3_prepare_v2(ppDb, [sql UTF8String], -1, &statement, nil) != SQLITE_OK)
        {
            NSLog(@"删除表失败！");
            return  NO;
        }
        
        int success = sqlite3_step(statement);
        // 释放资源
        sqlite3_finalize(statement);
        if (success != SQLITE_DONE)
        {
            NSLog(@"删除表失败,未知原因提前结束！");
            return NO;
        }
        
    }
    @catch (NSException *e)
    {
        NSLog(@"%@",e);
    }
   //删除表成功
    return YES;
}

+(BOOL)UpdateTableWithSql:(NSString *)sql {
    if (![SQLiteBase GetInstance].DB_Open)
    {
        if(![SQLiteBase OpenDB])
        {
            NSLog(@"创建表格失败,原因打开数据库出错！");
            return NO;
        }
    }
    
    sqlite3_stmt *statement;
    //验证sql语句是否成功
    const char *key = [[SQLiteBase GetInstance].DB_PassWord UTF8String];
    sqlite3_key(ppDb, key, strlen(key));
    if(sqlite3_prepare_v2(ppDb, [sql UTF8String], -1, &statement, nil) != SQLITE_OK)
    {
        NSLog(@"创建表格失败！");
        return  NO;
    }
    
    int success = sqlite3_step(statement);
    sqlite3_finalize(statement);
    if (success != SQLITE_DONE)
    {
        NSLog(@"在创建表格的过程中出错，创建没有进行完！");
        return NO;
    }
    
    return YES;
}

+(BOOL)isExistTableWithSql:(NSString *)sql {
    // 打开数据库
    if (![SQLiteBase GetInstance].DB_Open)
    {
        if(![SQLiteBase OpenDB])
        {
            NSLog(@"查询数据失败,打开数据库出错！");
            return NO;
        }
    }
    
    sqlite3_stmt *statement;
    //验证sql语句是否成功
    const char *key = [[SQLiteBase GetInstance].DB_PassWord UTF8String];
    sqlite3_key(ppDb, key, strlen(key));
    // 预编译和解析SQL文本，准备执行
    if (sqlite3_prepare_v2(ppDb, [sql UTF8String], -1, &statement, NULL) != SQLITE_OK)
    {
        return NO;
    }
    
    BOOL isExist = NO;
    while(sqlite3_step(statement) == SQLITE_ROW)
    {
        isExist = YES;
    }
    
    // 释放资源
    sqlite3_finalize(statement);
    // 未找到记录
    return isExist;
}

+(NSMutableArray *)GetNeedRecordWithSql:(NSString *)sql {
    // 打开数据库
    if (![SQLiteBase GetInstance].DB_Open)
    {
        if(![SQLiteBase OpenDB])
        {
            NSLog(@"查询数据失败,打开数据库出错！");
            return nil;
        }
    }
    
    sqlite3_stmt *statement;
    //验证sql语句是否成功
    const char *key = [[SQLiteBase GetInstance].DB_PassWord UTF8String];
    sqlite3_key(ppDb, key, strlen(key));
    // 预编译和解析SQL文本，准备执行
    if (sqlite3_prepare_v2(ppDb, [sql UTF8String], -1, &statement, NULL) != SQLITE_OK)
    {
        NSLog(@"Error: failed to prepare statement with message");
        return nil;
    }
    // 存放查询结果
    NSMutableArray *tmpNeededDataArr = [[NSMutableArray alloc] init];
    
    
    // 获得结果集
    while(sqlite3_step(statement) == SQLITE_ROW)
    {
        int count = sqlite3_data_count(statement);
        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:count];
        for(int i = 0;i<count;++i)
        {
            const char *cKey = sqlite3_column_name(statement,i);
            NSString *key = @"";
            if(cKey!=NULL)
            {
                key =[NSString stringWithUTF8String:cKey];
            }
            
            char *cValue = (char *)sqlite3_column_text(statement, i);
            NSString *value = @"";
            if (cValue != NULL) {
                value = [NSString stringWithUTF8String: cValue];
            }
            [dic setObject:value forKey:key];
        }
        
        [tmpNeededDataArr addObject:dic];
        
    }
    
    // 释放资源
    sqlite3_finalize(statement);
    
    //查询数据成功！
    return tmpNeededDataArr;
}
@end

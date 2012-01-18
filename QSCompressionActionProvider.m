

#import "QSCompressionActionProvider.h"

#import <QSCore/QSCore.h>


# define pArchiveUtility @"/System/Library/CoreServices/Archive Utility.app"
# define kFileDecompressAction @"QSFileDecompressAction"
# define kFileCompressAction @"QSFileCompressAction"

# define kArchiveUtilityBundleID @"com.apple.archiveutility"

//# import <StuffIt/StuffIt.h>

@implementation QSCompressionActionProvider

-(NSString *)copyMultipleSources:(NSArray *)paths
{
	// Create a unique temp folder
	NSString *tempDirectoryTemplate =
    [NSTemporaryDirectory() stringByAppendingPathComponent:@"XXXXXX"];
	const char *tempDirectoryTemplateCString =
    [tempDirectoryTemplate fileSystemRepresentation];
	char *tempDirectoryNameCString =
    (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
	strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);
	char *result = mkdtemp(tempDirectoryNameCString);
	
	NSString *tempDirectoryPath =
    [[NSFileManager defaultManager]
	 stringWithFileSystemRepresentation:tempDirectoryNameCString
	 length:strlen(result)];
	free(tempDirectoryNameCString);
	
	// Put them all in a folder called Archive to make it look nice
	tempDirectoryPath = [tempDirectoryPath stringByAppendingFormat:@"/Archive"];
	// Move the files / folders in the directory
	NSTask *rsync = [NSTask taskWithLaunchPath:@"/usr/bin/rsync" arguments:[[[NSArray arrayWithObject:@"-auzEq"] arrayByAddingObjectsFromArray:paths] arrayByAddingObject:tempDirectoryPath]];
	[rsync launch];
	[rsync waitUntilExit];
	
	// Return the temp folder/Archive location
	return tempDirectoryPath;	
}

- (NSString *)temporaryPath{
	NSString *destinationPath=[NSTemporaryDirectory() stringByAppendingPathComponent:@"Quicksilver"];
	NSFileManager *fm=[NSFileManager defaultManager];
	[fm createDirectoriesForPath:destinationPath];
	return destinationPath;
}

- (BOOL)tgzCompress:(NSArray *)paths destination:(NSString *)destinationPath{
	NSTask *task=[[[NSTask alloc]init]autorelease];
    [task setLaunchPath:@"/usr/bin/tar"];
    NSMutableArray *arguments=[NSMutableArray arrayWithObjects:@"-zcf",destinationPath,nil];
   for(NSString *path in paths){
		[arguments addObject:@"-C"];
		[arguments addObject:[path stringByDeletingLastPathComponent]];
		[arguments addObject:[path lastPathComponent]];
	}
	[task setArguments:arguments];
	[task launch];
	[task waitUntilExit];
	return [task terminationStatus]==0;	
}
- (BOOL)tbzCompress:(NSArray *)paths destination:(NSString *)destinationPath{
	NSTask *task=[[[NSTask alloc]init]autorelease];
    [task setLaunchPath:@"/usr/bin/tar"];
    NSMutableArray *arguments=[NSMutableArray arrayWithObjects:@"-jcf",destinationPath,nil];
   for(NSString *path in paths){
		[arguments addObject:@"-C"];
		[arguments addObject:[path stringByDeletingLastPathComponent]];
		[arguments addObject:[path lastPathComponent]];
	}
	[task setArguments:arguments];
	[task launch];
	[task waitUntilExit];
	return [task terminationStatus]==0;	
}
- (BOOL)cpgzCompress:(NSArray *)paths destination:(NSString *)destinationPath{
	
	NSTask *task=[[[NSTask alloc]init]autorelease];
    [task setLaunchPath:@"/usr/bin/ditto"];
    NSMutableArray *arguments=[NSMutableArray arrayWithObjects:@"-c",@"-z",@"-rsrc",@"--keepParent",nil];
	if ([paths count] > 1)
	{
		NSString *tempPath = [self copyMultipleSources:paths];
		[arguments addObject:tempPath];
	}
	else
		[arguments addObjectsFromArray:paths];
	
    [arguments addObject: destinationPath];
    [task setArguments:arguments];
    [task launch];
    [task waitUntilExit];
	return [task terminationStatus]==0;	
}
- (BOOL)cpioCompress:(NSArray *)paths destination:(NSString *)destinationPath{
	
	NSTask *task=[[[NSTask alloc]init]autorelease];
    [task setLaunchPath:@"/usr/bin/ditto"];
    NSMutableArray *arguments=[NSMutableArray arrayWithObjects:@"-c",@"-rsrc",@"--keepParent",nil];
	if ([paths count] > 1)
	{
		NSString *tempPath = [self copyMultipleSources:paths];
		[arguments addObject:tempPath];
	}
	else
		[arguments addObjectsFromArray:paths];
    [arguments addObject: destinationPath];
    [task setArguments:arguments];
    [task launch];
    [task waitUntilExit];
	return [task terminationStatus]==0;	
}


- (BOOL)zipCompress:(NSArray *)paths destination:(NSString *)destinationPath{
	
	NSTask *task = [[[NSTask alloc]init]autorelease];
	[task setLaunchPath:@"/usr/bin/ditto"];
    NSMutableArray *arguments=[NSMutableArray arrayWithObjects:@"-c",@"-k",@"-rsrc",@"--keepParent",nil];

	// If there's more than 1 source directory
	// Move all the folders into one folder named 'archive' in the temp folder
	if([paths count] > 1) 
	{
		NSString *tempPath = [self copyMultipleSources:paths];
		[arguments addObject:tempPath];
	}
	else
		[arguments addObjectsFromArray:paths];
    [arguments addObject: destinationPath];
    [task setArguments:arguments];
    [task launch];
	//NSLog(@"task %@", task);
    [task waitUntilExit];
	return [task terminationStatus]==0;	
}



- (QSObject *)compressFile:(QSObject *)dObject {
	return [self compressFile:dObject withFormat:nil];
}
	
- (NSArray *)validIndirectObjectsForAction:(NSString *)action directObject:(QSObject *)dObject{
	NSMutableArray *array=[NSMutableArray array];
    NSBundle *archiveUtilityBundle = [NSBundle bundleWithIdentifier:kArchiveUtilityBundleID];
    
	foreachkey(ident,compressor,[QSReg tableNamed:@"QSFileCompressors"]){
		QSObject *object=[QSObject objectWithString:ident name:ident type:@"qs.filecompressortype"];
		NSString *iconName=[compressor objectForKey:@"icon"];
        // Attempt to obtain icon from Archive Utility resources folder
        NSImage *icon = [QSResourceManager imageNamed:iconName inBundle:archiveUtilityBundle];
        if (!icon) {
            [object setObject:kArchiveUtilityBundleID forMeta:kQSObjectIconName];
        }
        else {
            [object setIcon:icon];
        }
		[array addObject:object];
	}
	return array;
}

- (QSObject *)compressFile:(QSObject *)dObject withFormat:(QSObject *)iObject{
		
	NSArray *sourcePaths=[dObject validPaths];
	
	NSString *type=[iObject stringValue];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (!type)type=[defaults stringForKey:@"QSCompressionDefaultType"];
	if (!type)type=@"zip";
	BOOL useTempFile=[defaults boolForKey:@"QSCompressionCreateTempFile"];
	
	
	NSString *destinationPath=nil;
	if (useTempFile){
		destinationPath= [[self temporaryPath] stringByAppendingFormat:@"/Archive"];
	}else{
		destinationPath=[[sourcePaths lastObject]stringByDeletingLastPathComponent];
	}
	
	if ([sourcePaths count]>1){
		destinationPath=[destinationPath stringByAppendingPathComponent:@"Archive"];
	}else{
		destinationPath=[destinationPath stringByAppendingPathComponent:
			[[[sourcePaths lastObject]lastPathComponent]stringByDeletingPathExtension]];
	}
	
	
	
	NSDictionary *info=[[QSReg tableNamed:@"QSFileCompressors"]objectForKey:type];
	NSString *extension=[info objectForKey:@"extension"];
	if (extension)
		destinationPath=[destinationPath stringByAppendingPathExtension:extension];
	destinationPath=[destinationPath firstUnusedFilePath];
	//NSLog(@"info %@ %@",info,destinationPath);
	BOOL success=(BOOL)[self performSelector:NSSelectorFromString([info objectForKey:@"selector"]) withObject:sourcePaths withObject:destinationPath];
	if (success){
		[[NSWorkspace sharedWorkspace] noteFileSystemChanged:[destinationPath stringByDeletingLastPathComponent]];
		return [QSObject fileObjectWithPath:destinationPath];
	}else{
		NSBeep();
		return nil;
	}
	return nil;
}


- (QSObject *)decompressFile:(QSObject *)dObject{        
    for(NSString *path in [dObject arrayForType:QSFilePathType]) {
        [[NSWorkspace sharedWorkspace] openFile:path withApplication:pArchiveUtility];
    }
    return nil;
}
@end

#import "QSCompressionActionProvider.h"
#import <QSCore/QSObject_FileHandling.h>

# define pArchiveUtility @"/System/Library/CoreServices/Archive Utility.app"
# define kFileDecompressAction @"QSFileDecompressAction"
# define kFileCompressAction @"QSFileCompressAction"

# define kArchiveUtilityBundleID @"com.apple.archiveutility"

//# import <StuffIt/StuffIt.h>

@implementation QSCompressionActionProvider

- (BOOL)stripMacFiles {
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"QSCompressionStripMacFiles"];
}

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
    NSMutableArray *arguments=[NSMutableArray array];
	if ([self stripMacFiles]) {
		[arguments addObjectsFromArray:@[@"--exclude=\"._*\"", @"--exclude='__MACOSX'", @"--exclude='.DS_Store'", @"--disable-copyfile"]];
	}
	[arguments addObjectsFromArray:@[@"-zcf", destinationPath]];
    for(NSString *path in paths){
		[arguments addObject:@"-C"];
		[arguments addObject:[path stringByDeletingLastPathComponent]];
		[arguments addObject:[path lastPathComponent]];
	}
    return [self runPath:@"LANG=UTF-8 /usr/bin/tar" arguments:arguments];
}

- (BOOL)tbzCompress:(NSArray *)paths destination:(NSString *)destinationPath{
    NSMutableArray *arguments=[NSMutableArray array];
	if ([self stripMacFiles]) {
		[arguments addObjectsFromArray:@[@"--exclude=\"._*\"", @"--exclude='__MACOSX'", @"--exclude='.DS_Store'", @"--disable-copyfile"]];
	}
	[arguments addObjectsFromArray:@[@"-jcf", destinationPath]];
    for(NSString *path in paths){
		[arguments addObject:@"-C"];
		[arguments addObject:[path stringByDeletingLastPathComponent]];
		[arguments addObject:[path lastPathComponent]];
	}
    return [self runPath:@"/usr/bin/tar" arguments:arguments];
    
}

- (BOOL)cpgzCompress:(NSArray *)paths destination:(NSString *)destinationPath{
	
    NSMutableArray *arguments=[NSMutableArray arrayWithObjects:@"-c",@"-z",[self stripMacFiles] ? @"--norsrc" : @"-rsrc",@"--keepParent",nil];
	if ([paths count] > 1)
	{
		NSString *tempPath = [self copyMultipleSources:paths];
		[arguments addObject:tempPath];
	}
	else
		[arguments addObjectsFromArray:paths];
	
    [arguments addObject: destinationPath];
    return [self runPath:@"/usr/bin/ditto" arguments:arguments];

}

- (BOOL)cpioCompress:(NSArray *)paths destination:(NSString *)destinationPath{
	
    NSMutableArray *arguments=[NSMutableArray arrayWithObjects:@"-c",[self stripMacFiles] ? @"--norsrc" : @"-rsrc",@"--keepParent",nil];
	if ([paths count] > 1)
	{
		NSString *tempPath = [self copyMultipleSources:paths];
		[arguments addObject:tempPath];
	}
	else
		[arguments addObjectsFromArray:paths];
    [arguments addObject: destinationPath];
    return [self runPath:@"/usr/bin/ditto" arguments:arguments];

}

- (BOOL)p7zipCompress:(NSArray *)paths destination:(NSString *)destinationPath{
    // 7zr is the minimal binary version. See https://wiki.archlinux.org/index.php/p7zip#Differences_between_7z.2C_7za_and_7zr_binaries
    
    NSString *p7zBinary = [[NSBundle bundleForClass:[self class]] pathForResource:@"7zr" ofType:@""];
    NSMutableArray *arguments=[NSMutableArray arrayWithObjects:@"a",destinationPath,nil];
    [arguments addObjectsFromArray:paths];
    return [self runPath:p7zBinary arguments:arguments];
}

- (BOOL)zipCompress:(NSArray *)paths destination:(NSString *)destinationPath{
	
	NSMutableArray *arguments=[NSMutableArray arrayWithObjects:@"-c",@"-k", [self stripMacFiles] ? @"--norsrc" : @"-rsrc" ,@"--keepParent",nil];

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
    return [self runPath:@"/usr/bin/ditto" arguments:arguments];
}


- (BOOL)runPath:(NSString *)path arguments:(NSArray *)arguments {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:path];
    [task setArguments:arguments];
    [task launch];
    [task waitUntilExit];
    return [task terminationStatus] == 0;
}

- (QSObject *)compressFile:(QSObject *)dObject {
	return [self compressFile:dObject withFormat:nil];
}
	
- (NSArray *)validIndirectObjectsForAction:(NSString *)action directObject:(QSObject *)dObject{
	NSMutableArray *array=[NSMutableArray array];
    NSBundle *archiveUtilityBundle = [NSBundle bundleWithIdentifier:kArchiveUtilityBundleID];
    
	foreachkey(ident, compressor,[QSReg tableNamed:@"QSFileCompressors"]){
        NSString *desc = (__bridge_transfer NSString *)UTTypeCopyDescription(((__bridge CFStringRef)ident));
        
        NSString *name = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)ident, kUTTagClassFilenameExtension);
		QSObject *object = [QSObject objectWithString:ident name:name ? name : ident type:@"qs.filecompressortype"];
        if (desc) {
            [object setDetails:desc];
        }
		NSString *iconName = [compressor objectForKey:@"icon"];
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
	if (!type) {
        type=[defaults stringForKey:@"QSCompressionDefaultType"];
    }
	if (!type) {
        type = @"public.zip-archive";
    }

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
        NSString *destinationFileName = [[sourcePaths lastObject] lastPathComponent];
        if (![dObject isFolder]) {
            destinationFileName = [destinationFileName stringByDeletingPathExtension];
        }
		destinationPath=[destinationPath stringByAppendingPathComponent:destinationFileName];
	}
	
	// Make sure we have a UTI
	type = QSUTIForAnyTypeString(type);
    
	NSDictionary *info=[[QSReg tableNamed:@"QSFileCompressors"] objectForKey:type];
    if (!info) {
        NSLog(@"Could not find handler to compress %@. No related handler could be found. Aborting", type);
        QSShowAppNotifWithAttributes(@"QSCompressionPlugin", NSLocalizedStringForThisBundle(@"Unable to compress file", @"Error notif title"), [NSString stringWithFormat:NSLocalizedStringForThisBundle(@"An error occurred trying to compress %@", @"Error notif text"), sourcePaths]);
    }
    
	NSString *extension = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)type, kUTTagClassFilenameExtension);
    if (!extension) {
        [info objectForKey:@"extension"];
    }
	if (extension)
		destinationPath=[destinationPath stringByAppendingPathExtension:extension];
	destinationPath=[destinationPath firstUnusedFilePath];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    // no leaks here, since the return value of all xxxCompress:destination methods is a BOOL
	BOOL success = (BOOL) [self performSelector:NSSelectorFromString([info objectForKey:@"selector"]) withObject:sourcePaths withObject:destinationPath];
#pragma clang diagnostic pop
	if (success){
		[[NSWorkspace sharedWorkspace] noteFileSystemChanged:[destinationPath stringByDeletingLastPathComponent]];
        QSObject *archive = [QSObject fileObjectWithPath:destinationPath];
        NSDictionary *info = @{@"object": archive};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"QSEventNotification" object:@"QSFileCompressComplete" userInfo:info];
		return archive;
	}else{
		NSBeep();
	}
	return nil;
}


- (QSObject *)decompressFile:(QSObject *)dObject{        
    for (QSObject *archive in [dObject splitObjects]) {
        
        bool is7Z = QSTypeConformsTo([archive fileUTI], @"org.7-zip.7-zip-archive");
        
        NSString *path = [archive objectForType:QSFilePathType];
        
        if (is7Z) {
            NSTask *task = [[NSTask alloc] init];
            // 7zr is the minimal binary version. See https://wiki.archlinux.org/index.php/p7zip#Differences_between_7z.2C_7za_and_7zr_binaries
            NSString *p7zBinary = [[NSBundle bundleForClass:[self class]] pathForResource:@"7zr" ofType:@""];
            [task setLaunchPath:p7zBinary];
            [task setCurrentDirectoryPath:[path stringByDeletingLastPathComponent]];
            // -aou: Auto rename all (avoid conflict with existing files).
            // This behavious is similar to Archive Utility, except with underscores instead of spaces.
            NSMutableArray *arguments=[NSMutableArray arrayWithObjects:@"x",@"-aou",path,nil];
            [task setArguments:arguments];
            [task launch];
            [task waitUntilExit];
            
        }else {
            // Use Archive Utility
            [[NSWorkspace sharedWorkspace] openFile:path withApplication:pArchiveUtility];
        }
        
        NSDictionary *info = @{@"object": archive};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"QSEventNotification" object:@"QSFileDecompressComplete" userInfo:info];
    }
    return nil;
}
@end

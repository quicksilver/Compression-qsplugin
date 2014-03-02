@interface QSCompressionActionProvider : QSActionProvider
{
}

- (QSObject *)compressFile:(QSObject *)dObject withFormat:(QSObject *)iObject;
- (QSObject *)compressFile:(QSObject *)dObject;

@end

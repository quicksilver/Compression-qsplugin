

#import <Foundation/Foundation.h>

#import <QSCore/QSActionProvider.h>


@interface QSCompressionActionProvider : QSActionProvider
{
}

- (QSObject *)compressFile:(QSObject *)dObject withFormat:(QSObject *)iObject;

@end

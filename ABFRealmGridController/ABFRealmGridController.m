//
//  ABFRealmGridController.m
//  ABFRealmGridControllerExample
//
//  Created by Adam Fish on 8/25/15.
//  Copyright (c) 2015 Adam Fish. All rights reserved.
//

#import "ABFRealmGridController.h"

#import <Realm/Realm.h>
#import <RBQFetchedResultsController/RBQFetchedResultsController.h>
#import <RBQFetchedResultsController/RBQFetchRequest.h>

#pragma mark - Constants
static NSString * const reuseIdentifier = @"Cell";

typedef void(^ABFCollectionViewUpdateBlock)();

#pragma mark - NSMutableArray CollectionViewUpdates Category

@interface NSMutableArray (CollectionViewUpdates)

- (void)addUpdateBlock:(ABFCollectionViewUpdateBlock)updateBlock;

- (void)performUpdates;

@end

@implementation NSMutableArray (CollectionViewUpdates)

- (void)addUpdateBlock:(ABFCollectionViewUpdateBlock)updateBlock
{
    [self addObject:updateBlock];
}

- (void)performUpdates
{
    for (ABFCollectionViewUpdateBlock updateBlock in self) {
        updateBlock();
    }
}

@end

#pragma mark - ABFRealmGridController

@interface ABFRealmGridController () <RBQFetchedResultsControllerDelegate>

@property (assign, nonatomic) BOOL viewLoaded;

@property (strong, nonatomic) NSMutableArray *updateBlocks;

@end

@implementation ABFRealmGridController
@synthesize realmConfiguration = _realmConfiguration;

#pragma mark - Initialization

- (id)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
    self = [super initWithCollectionViewLayout:layout];
    
    if (self) {
        [self baseInit];
    }
    
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil
                           bundle:nibBundleOrNil];
    
    if (self) {
        [self baseInit];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self baseInit];
    }
    
    return self;
}

- (id)init
{
    self = [super init];
    
    if (self) {
        [self baseInit];
    }
    
    return self;
}

- (void)baseInit
{
    _fetchedResultsController = [[RBQFetchedResultsController alloc] init];
    _fetchedResultsController.delegate = self;
}

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.fetchedResultsController performFetch];
    
    self.viewLoaded = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Setters

- (void)setEntityName:(NSString *)entityName
{
    _entityName = entityName;
    
    [self updateFetchedResultsController];
}

- (void)setBasePredicate:(NSPredicate *)basePredicate
{
    _basePredicate = basePredicate;
    
    [self updateFetchedResultsController];
}

- (void)setSortDescriptors:(NSArray *)sortDescriptors
{
    _sortDescriptors = sortDescriptors;
    
    [self updateFetchedResultsController];
}

- (void)setSectionNameKeyPath:(NSString *)sectionNameKeyPath
{
    _sectionNameKeyPath = sectionNameKeyPath;
    
    [self updateFetchedResultsController];
}

- (void)setRealmConfiguration:(RLMRealmConfiguration *)realmConfiguration
{
    _realmConfiguration = realmConfiguration;
    
    [self updateFetchedResultsController];
}
#pragma mark - Getters

- (RLMRealmConfiguration *)realmConfiguration
{
    if (! _realmConfiguration) {
        return [RLMRealmConfiguration defaultConfiguration];
    }
    
    return _realmConfiguration;
}

- (RLMRealm *)realm
{
    return [RLMRealm realmWithConfiguration:self.realmConfiguration error:nil];
}

#pragma mark - Private

- (void)updateFetchedResultsController
{
    if (self.entityName &&
        !self.viewLoaded) {
        
        RBQFetchRequest *fetchRequest = [RBQFetchRequest fetchRequestWithEntityName:self.entityName
                                                                            inRealm:self.realm
                                                                          predicate:self.basePredicate];
        
        [self.fetchedResultsController updateFetchRequest:fetchRequest
                                       sectionNameKeyPath:self.sectionNameKeyPath
                                           andPeformFetch:NO];
    }
    else if (self.entityName) {
        
        typeof(self) __weak weakSelf = self;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            RBQFetchRequest *fetchRequest = [RBQFetchRequest fetchRequestWithEntityName:weakSelf.entityName
                                                                                inRealm:weakSelf.realm
                                                                              predicate:weakSelf.basePredicate];
            
            [weakSelf.fetchedResultsController updateFetchRequest:fetchRequest
                                               sectionNameKeyPath:weakSelf.sectionNameKeyPath
                                                   andPeformFetch:weakSelf.viewLoaded];
            
            if (weakSelf.viewLoaded) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.collectionView reloadData];
                });
            }
        });
    }
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [self.fetchedResultsController numberOfSections];
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [self.fetchedResultsController numberOfRowsForSectionIndex:section];
}

#pragma mark - <RBQFetchedResultsControllerDelegate>

- (void)controllerWillChangeContent:(RBQFetchedResultsController *)controller
{
    self.updateBlocks = [NSMutableArray array];
}

- (void)controller:(RBQFetchedResultsController *)controller
   didChangeObject:(RBQSafeRealmObject *)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UICollectionView *collectionView = self.collectionView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            {
                [self.updateBlocks addUpdateBlock:^{
                    [collectionView insertItemsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]];
                }];
            }
                break;
        case NSFetchedResultsChangeDelete:
            {
                [self.updateBlocks addUpdateBlock:^{
                    [collectionView deleteItemsAtIndexPaths:[NSArray arrayWithObject:indexPath]];
                }];
            }
            break;
        case NSFetchedResultsChangeUpdate:
            {
                [self.updateBlocks addUpdateBlock:^{
                    if ([[collectionView indexPathsForVisibleItems] containsObject:indexPath]) {
                        [collectionView reloadItemsAtIndexPaths:[NSArray arrayWithObject:indexPath]];
                    }
                }];
            }
            break;
        case NSFetchedResultsChangeMove:
            {
                [self.updateBlocks addUpdateBlock:^{
                    [collectionView deleteItemsAtIndexPaths:[NSArray arrayWithObject:indexPath]];
                    [collectionView insertItemsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]];
                }];
            }
            break;
    }
}

- (void)controller:(RBQFetchedResultsController *)controller
  didChangeSection:(RBQFetchedResultsSectionInfo *)section
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    UICollectionView *collectionView = self.collectionView;
    
    if (type == NSFetchedResultsChangeInsert) {
        NSIndexSet *insertedSection = [NSIndexSet indexSetWithIndex:sectionIndex];
        
        [self.updateBlocks addUpdateBlock:^{
            [collectionView insertSections:insertedSection];
        }];
    }
    else if (type == NSFetchedResultsChangeDelete) {
        NSIndexSet *deletedSection = [NSIndexSet indexSetWithIndex:sectionIndex];
        
        [self.updateBlocks addUpdateBlock:^{
            [collectionView deleteSections:deletedSection];
        }];
    }
}

- (void)controllerDidChangeContent:(RBQFetchedResultsController *)controller
{
    NSMutableArray *updateBlocks = self.updateBlocks;
    
    [self.collectionView performBatchUpdates:^{
        [updateBlocks performUpdates];
    } completion:nil];
}

@end

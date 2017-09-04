# Apabi_QA

## 1、写一个下载类，看文件```ZYDownloader```

## 2、设计一个电梯调度算法


## 3、写出一个判断在三角形内
  1、点P和点C在直线AB同侧    
  2、点P和点B在直线AC同侧      
  3、点P和点A在直线BC同侧
  
  ```objc
  + (BOOL)zy_point:(CGPoint)point inTriangleVertexPointsArea:(NSArray<NSValue *> *)vertexPoints {
    if (vertexPoints.count == 3) {
        CGPoint point0 = [vertexPoints[0] CGPointValue];
        CGPoint point1 = [vertexPoints[1] CGPointValue];
        CGPoint point2 = [vertexPoints[2] CGPointValue];
        
        CGFloat signOfTrig = (point1.x - point0.x)*(point2.y - point0.y) - (point1.y - point0.y)*(point2.x - point0.x);
        
        CGFloat signOfAB = (point1.x - point0.x)*(point.y - point0.y) - (point1.y - point0.y)*(point.x - point0.x);
        CGFloat signOfCA = (point0.x - point2.x)*(point.y - point2.y) - (point0.y - point2.y)*(point.x - point2.x);
        CGFloat signOfBC = (point2.x - point1.x)*(point.y - point1.y) - (point2.y - point1.y)*(point.x - point1.x);
        
        BOOL d1 = (signOfTrig * signOfAB > 0);
        BOOL d2 = (signOfTrig * signOfCA > 0);
        BOOL d3 = (signOfTrig * signOfBC > 0);
        return d1 && d2 && d3;
    }
    return NO;
} 
  ```     
  
  
## 4、 XCode（iOS程序）和其他编辑器相比独有的一些特点。
1、 官方指定的编译器；    
2、 可以使用StoryBoard；    
3、 自带模拟器，其他的都没有。
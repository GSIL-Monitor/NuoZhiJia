//
//  StartsViewController.m
//  Cervella
//
//  Created by Justin on 2017/6/29.
//  Copyright © 2017年 Justin. All rights reserved.
//

#import "StartsViewController.h"

#import "BindViewController.h"

#import "ColorsSliderView.h"

#import "ImageTitleDetialView.h"
#import "SelectView.h"

#import "BluetoothStatusView.h"

#import "TreatInfo.h"


#define FrequencySelectors @[@"0.5Hz",@"1.5Hz",@"100Hz"]
#define FrequencySelectorsInteger @[@"1",@"2",@"3"]

#define TimeSelectors @[@"10min",@"20min",@"30min",@"40min",@"50min",@"60min"]
#define TimeSelectorsInteger @[@"600",@"1200",@"1800",@"2400",@"3000",@"3600"]

@interface StartsViewController ()<NSXMLParserDelegate,NSURLConnectionDelegate, ColorsSliderViewDelegate, BluetoothDelegate>

//接口请求和解析
@property (strong,nonatomic) NSMutableData *webData;
@property (strong,nonatomic) NSMutableString *soapResults;
@property (strong,nonatomic) NSXMLParser *xmlParser;
@property (nonatomic) BOOL elementFound;
@property (strong,nonatomic) NSString *matchingElement;
@property (strong,nonatomic) NSURLConnection *conn;



//block
@property (assign,nonatomic) NSInteger frequencySelector;
@property (assign,nonatomic) NSInteger timeSelector;
@property (assign,nonatomic) NSInteger timeDuration;//倒计时总时长 s

//@property (strong,nonatomic) NSArray *scanednEquipments;

@property (strong,nonatomic) ImageTitleDetialView *frequencyView;;
@property (strong,nonatomic) SelectView *frequencySelectView;
@property (strong,nonatomic) ImageTitleDetialView *timeView;
@property (strong,nonatomic) SelectView *timeSelectView;
@property (strong,nonatomic) BluetoothStatusView *bluetoothStatusView;


@end

@implementation StartsViewController
{
    
    NSInteger intensityLevel;
    UILabel   *intensityLevelLabel;         //用来显示电流强度大小

    ColorsSliderView *colorsSliderView;
    
    NSInteger timeRemaining;            //剩余时间
    NSTimer *countDownTimer;

    
    DataBaseOpration *dbOpration;
    
    NSDate *beginDate;
    NSDate *endDate;
    
    BOOL isWear;
    
    //当前治疗
    NSTimer *saveTreatInfoTimer;
    TreatInfo *treatInfoTmp;
    
}
@synthesize webData,soapResults,xmlParser,elementFound,matchingElement,conn;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.view.backgroundColor = [UIColor whiteColor];
    //注册链接蓝牙通知
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendBluetoothInfoValue:) name:@"connectBLE" object:nil];
    //注册解绑通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(freeBluetoothInfo) name:@"Free" object:nil];
    //注册切换用户通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeUser) name:@"ChangeUser" object:nil];
    
    //默认参数
    [self defaultData];
    
    /**************强度***************/
    [self addSectionOne];
    /***************频率和时间**************/
    [self addSectionTwo];
    /***************治疗**************/
    [self addSectionThree];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    self.bluetooth.delegate = self;


}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [countDownTimer invalidate];
    [saveTreatInfoTimer invalidate];
}

#pragma  mark - init
- (void)defaultData {
    intensityLevel = 1;
    self.frequencySelector = 2;
    self.timeSelector =  2;
    self.timeDuration = [TimeSelectorsInteger[self.timeSelector] integerValue];
    treatInfoTmp = nil;
}

/***************强度**************/
-(void)addSectionOne
{
    UIImageView *intensityView=[[UIImageView alloc] initWithFrame:CGRectMake(SCREENWIDTH/12, CES_SCREENH_HEIGHT/25+CES_SCREENH_HEIGHT/30 - 5, 30, 30)];
    [intensityView setImage:[UIImage imageNamed:@"ces_strength"]];
    
    UILabel *electricLabel=[[UILabel alloc] initWithFrame:CGRectMake(SCREENWIDTH/12+SCREENWIDTH/10 + 10, CES_SCREENH_HEIGHT/30+CES_SCREENH_HEIGHT/30 - 5, SCREENWIDTH/2, 40)];
    electricLabel.font = [UIFont systemFontOfSize:20];
    electricLabel.text=@"Intensity Level";
    
    intensityLevelLabel=[[UILabel alloc] initWithFrame:CGRectMake(SCREENWIDTH-SCREENWIDTH/4, CES_SCREENH_HEIGHT/30+CES_SCREENH_HEIGHT/30 - 5 , SCREENWIDTH/8, 40)];
    intensityLevelLabel.font = [UIFont systemFontOfSize:20];
    intensityLevelLabel.textColor = [UIColor redColor];
    intensityLevelLabel.text = [NSString stringWithFormat:@"%ld",(long)intensityLevel];
    [self.view addSubview:intensityView];
    [self.view addSubview:electricLabel];
    [self.view addSubview:intensityLevelLabel];
    
    colorsSliderView = [[ColorsSliderView alloc] init];
    colorsSliderView.frame = CGRectMake(40, SCREENHEIGHT/6.6, SCREENWIDTH - 80, 40);
    colorsSliderView.delegate = self;
    colorsSliderView.level = intensityLevel;
    [self.view addSubview:colorsSliderView];
}

#pragma mark - ColorsSliderViewDelegate
- (void)selectIndex:(NSInteger)index {
    if (self.bluetooth.equipment) {
        if (colorsSliderView.level < index) {
            colorsSliderView.level = colorsSliderView.level + 1;
        }
        else if (colorsSliderView.level > index) {
            colorsSliderView.level = colorsSliderView.level - 1;
        }
        
        intensityLevel = colorsSliderView.level;
        intensityLevelLabel.text = [NSString stringWithFormat:@"%ld",(long)intensityLevel];
        
        //设置电流强度
        if (self.bluetooth.connectSate == ConnectStateNormal) {
            [self.bluetooth changeLevel:intensityLevel];
        }
    }
}

/***************frequency time**************/
-(void)addSectionTwo
{
    self.frequencyView = [[ImageTitleDetialView alloc] init];
    self.frequencyView.frame = CGRectMake(SCREENWIDTH/12,
                                     CES_SCREENH_HEIGHT/25+CES_SCREENH_HEIGHT*5/16+CES_SCREENH_HEIGHT/60 - 20,
                                     SCREENWIDTH - 60,
                                     60);
    self.frequencyView.items = @[@{@"image":@"ces_freq",@"title":@"Frequency",@"detail":FrequencySelectors[self.frequencySelector]}];
    self.frequencyView.isCanSelect = NO;
    
    self.frequencySelectView = [[SelectView alloc] init];
    self.frequencySelectView.titile = @"请选择";
    self.frequencySelectView.items = FrequencySelectors;
    self.frequencySelectView.frame = CGRectMake(0, 0, SCREENWIDTH - 60, 150);
    __weak typeof (*&self) weakSelf = self;
   self.frequencySelectView.selectViewBlock = ^(NSInteger index) {
       if (weakSelf.bluetooth.equipment) {
           weakSelf.frequencySelector = index;
           weakSelf.frequencyView.items = @[@{@"image":@"ces_freq",@"title":@"Frequency",@"detail":FrequencySelectors[weakSelf.frequencySelector]}];
           //设置频率
           if (weakSelf.bluetooth.connectSate == ConnectStateNormal) {
               [weakSelf.bluetooth changeWorkModel:weakSelf.frequencySelector];
           }
       }
    };
    
    self.frequencyView.imageTitleDetailViewBlock = ^() {
        //显示电流强度选项
        weakSelf.frequencySelectView.selector = weakSelf.frequencySelector;
        [weakSelf.frequencySelectView showViewInView:weakSelf.view];
    };
    [self.view addSubview:self.frequencyView];
    
    self.timeView = [[ImageTitleDetialView alloc] init];
    self.timeView.frame = CGRectMake(SCREENWIDTH/12,
                                self.frequencyView.frame.origin.y + self.frequencyView.frame.size.height,
                                SCREENWIDTH - 60,
                                60);
    self.timeView.items = @[@{@"image":@"time",@"title":@"Duration",@"detail":TimeSelectors[self.timeSelector]}];
    self.timeView.isCanSelect = YES;

    self.timeSelectView = [[SelectView alloc] init];
    self.timeSelectView.titile = @"Selector";
    self.timeSelectView.items = TimeSelectors;
    self.timeSelectView.frame = CGRectMake(0, 0, SCREENWIDTH - 60, 270);
    self.timeSelectView.selectViewBlock = ^(NSInteger index) {
        //设置时间长度
        weakSelf.timeSelector = index;
        weakSelf.timeView.items = @[@{@"image":@"time",@"title":@"Time",@"detail":TimeSelectors[weakSelf.timeSelector]}];
        weakSelf.timeDuration = [TimeSelectorsInteger[index] integerValue];
        if (weakSelf.bluetoothStatusView.statusType == StatusTypeStart) {
            weakSelf.bluetoothStatusView.timers = weakSelf.timeDuration;
        }
    };
    
    self.timeView.imageTitleDetailViewBlock = ^() {
        //显示时间选项
        weakSelf.timeSelectView.selector  = weakSelf.timeSelector;
        [weakSelf.timeSelectView showViewInView:weakSelf.view];
    };
    [self.view addSubview:weakSelf.timeView];
    
    UIView *lineTopView = [[UIView alloc] initWithFrame:CGRectMake(SCREENWIDTH/12,
                                                                   self.frequencyView.frame.origin.y,
                                                                   SCREENWIDTH - 60,
                                                                   1.5)];
    lineTopView.backgroundColor = [UIColor grayColor];
    [self.view addSubview:lineTopView];
    
    UIView *lineCenterView = [[UIView alloc] initWithFrame:CGRectMake(SCREENWIDTH/12,
                                                                   self.timeView.frame.origin.y,
                                                                   SCREENWIDTH - 60,
                                                                   0.5)];
    lineCenterView.backgroundColor = [UIColor grayColor];
    [self.view addSubview:lineCenterView];
    
    UIView *linebottomView = [[UIView alloc] initWithFrame:CGRectMake(SCREENWIDTH/12,
                                                                      self.timeView.frame.origin.y + 54.0,
                                                                      SCREENWIDTH - 60,
                                                                      0.5)];
    linebottomView.backgroundColor = [UIColor grayColor];
//    [self.view addSubview:linebottomView];
}

/***************第四部分**************/
-(void)addSectionThree
{
    if (SCREENHEIGHT == 568) {
        self.bluetoothStatusView = [[BluetoothStatusView alloc] initWithFrame:CGRectMake((SCREENWIDTH - 160)/2.0, SCREENHEIGHT - 280, 160, 160)];

    } else if (SCREENHEIGHT == 667) {
        self.bluetoothStatusView = [[BluetoothStatusView alloc] initWithFrame:CGRectMake((SCREENWIDTH - 180)/2.0, SCREENHEIGHT - 330.0f, 180, 180)];

    } else if (SCREENHEIGHT == 736) {
        self.bluetoothStatusView = [[BluetoothStatusView alloc] initWithFrame:CGRectMake((SCREENWIDTH - 190)/2.0, SCREENHEIGHT - 360.0f, 190, 190)];
    } else if (SCREENHEIGHT == 812) {
        self.bluetoothStatusView = [[BluetoothStatusView alloc] initWithFrame:CGRectMake((SCREENWIDTH - 190)/2.0, SCREENHEIGHT - 410.0f, 190, 190)];
    }
    self.bluetoothStatusView.timers = self.timeDuration;
    self.bluetoothStatusView.statusType = StatusTypeNone;
    self.bluetoothStatusView.isCanTap = YES;
    
    __weak typeof (*&self) weakSelf = self;
    self.bluetoothStatusView.bluetoothStatusViewBlock = ^(StatusType statusType) {
        if (statusType == StatusTypeNone) {
            //绑定过直接链接
            if (weakSelf.bluetoothInfo) {
                for (Equipment *eq in weakSelf.bluetooth.equipments) {
                    if ([weakSelf.bluetoothInfo.peripheralIdentify isEqualToString:[eq.peripheral.identifier UUIDString]]) {
                        //链接蓝牙设备
                        [weakSelf.bluetooth connectEquipment:eq];
                        weakSelf.bluetoothStatusView.isCanTap = NO;
                        break;
                    }
                }
            } else {
                //点击绑定设备
                BindViewController *bindViewController=[[BindViewController alloc] initWithNibName:@"BindViewController" bundle:nil];
                bindViewController.bindFlag=@"1";
                bindViewController.bindViewControllerSelectEquiment = ^(Equipment *eq) {
                    for (Equipment *equipmemt in weakSelf.bluetooth.equipments) {
                        if ([[equipmemt.peripheral.identifier UUIDString] isEqualToString:[eq.peripheral.identifier UUIDString]]) {
                            [weakSelf.bluetooth connectEquipment:equipmemt];
                            weakSelf.bluetoothStatusView.isCanTap = NO;
                            break;
                        }
                    }
                };
                [weakSelf.navigationController pushViewController:bindViewController animated:YES];
            }

        } else if (statusType == StatusTypeStart) {
            //点解开始治疗
            [weakSelf blueStartWorkUI];

        } else if (statusType == StatusTypeStop) {
            //点击结束
            [weakSelf blueStopWorkUI];
        }
    };
    
    [self.view addSubview:self.bluetoothStatusView];
}
//开始治疗UI
- (void)blueStartWorkUI {
    //UI
    self.frequencyView.isCanSelect = NO;
    self.timeView.isCanSelect = NO;
    timeRemaining = self.timeDuration;
    self.bluetoothStatusView.statusType = StatusTypeStop;
    self.bluetoothStatusView.timers = self.timeDuration;
    treatInfoTmp =  nil;
    //开始治疗
    [self.bluetooth startWork];
    //倒计时
    [self timeCountDown];
    //定时保存治疗数据
    [self initTreatInfoTimer];
    
    beginDate = [NSDate date];
}
//停止治疗UI
- (void)blueStopWorkUI {
    //停止治疗
    [self.bluetooth endWork];
    //停止倒计时
    [countDownTimer invalidate];
    [saveTreatInfoTimer invalidate];
    
    //保存治疗数据到数据库
    endDate = [NSDate date];
    [self saveTreatInfo];
    beginDate = nil;
    endDate = nil;
    treatInfoTmp = nil;
    //UI
    self.frequencyView.isCanSelect = YES;
    self.timeView.isCanSelect = YES;
    timeRemaining = self.timeDuration;
    self.bluetoothStatusView.statusType = StatusTypeStart;
    self.bluetoothStatusView.timers = self.timeDuration;
    [self.bluetoothStatusView updateProgressWithPercent:0.001];
}

//倒计时
- (void)timeCountDown {
    countDownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(handleTimer) userInfo:nil repeats:YES];
}
//定时保存治疗数据
- (void)initTreatInfoTimer {
    saveTreatInfoTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(saveTreatInfo) userInfo:nil repeats:YES];
}

//倒计时处理
- (void)handleTimer {
    if (timeRemaining > 0) {
        timeRemaining = timeRemaining - 1;
        self.bluetoothStatusView.timers = timeRemaining;
        CGFloat precent = (self.timeDuration * 1.0 - timeRemaining * 1.0)/(self.timeDuration * 1.0);
        [self.bluetoothStatusView updateProgressWithPercent:precent];
    }
    else {
        [self blueStopWorkUI];
    }
}

//显示错误
- (void)showError:(NSError *)error {
    if (error) {
        //提出警告
        NSString *str = [NSString stringWithFormat:@"%@\n%@",error.localizedDescription, error.localizedRecoverySuggestion];
        UIAlertController *alertC = [UIAlertController alertControllerWithTitle:@"" message:str preferredStyle:(UIAlertControllerStyleAlert)];
        UIAlertAction *alert = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction *  action) {
            
        }];
        [alertC addAction:alert];
        [self presentViewController:alertC animated:YES completion:nil];
    }
}

#pragma mark 通知
//解除绑定
- (void)freeBluetoothInfo {
    if (self.bluetooth.equipment) {
        [self.bluetooth stopConnectEquipment:self.bluetooth.equipment];
    }
    [self blueStopWorkUI];
    self.bluetoothStatusView.statusType = StatusTypeNone;
    _bluetooth = nil;
}

- (void)changeUser {
    if (self.bluetooth.equipment) {
        [self.bluetooth stopConnectEquipment:self.bluetooth.equipment];
    }
    [self blueStopWorkUI];
    
    [self defaultData];
    self.bluetoothStatusView.statusType = StatusTypeNone;
    _bluetooth = nil;

}

#pragma mark -- BluetoothDelegate
- (void)scanedEquipments:(NSArray *)equipments {
    //搜索到设备
//    self.scanednEquipments = equipments;
}

- (void)connectState:(ConnectState)connectState Error:(NSError *)error {
    self.bluetoothStatusView.isCanTap = YES;

    if (connectState == ConnectStateNormal) { //正常链接成功
        self.bluetoothStatusView.statusType = StatusTypeStart;
        self.bluetoothStatusView.timers = self.timeDuration;
        //Pairing successful!
        jxt_showTextHUDTitleMessage(@"", @"Pairing successful!");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            jxt_dismissHUD();
        });
        //保存设备
        [self saveConnectEquiment];
        //上传服务器硬件设备
        [self postBindDevice:self.bluetooth.equipment.deviceCode];
    }
    else {
        [self showError:error];
    }
}

- (void)wearState:(WearState)wearState Error:(NSError *)error {
    if (wearState == WearStateNormal) {
        NSLog(@"WearStateNormal");
        if (!isWear) {
            [countDownTimer setFireDate:[NSDate date]];
            [saveTreatInfoTimer setFireDate:[NSDate date]];
        }
        isWear = YES;
    }
    else {
        //暂停倒计时
        if (isWear) {
            [countDownTimer setFireDate:[NSDate distantFuture]];
            [saveTreatInfoTimer setFireDate:[NSDate distantFuture]];

            //提出警告
            [self showError:error];
        }
        isWear = NO;
    }
}

//电池状态
- (void)battery:(NSUInteger )battery Error:(NSError *)error {
    [self showError:error];
}

#pragma mark - DataBaseOpration
- (void)saveConnectEquiment {
    //将选择的外设存储到数据库并关闭数据库
    dbOpration = [[DataBaseOpration alloc] init];
    
    BluetoothInfo *bluetoothInfo = [[BluetoothInfo alloc] init];
    bluetoothInfo.saveId = @"1";
    bluetoothInfo.peripheralIdentify = self.bluetooth.equipment.peripheral.identifier.UUIDString;
    bluetoothInfo.deviceName = self.bluetooth.equipment.peripheral.name;
    bluetoothInfo.deviceCode = self.bluetooth.equipment.deviceCode;
    bluetoothInfo.deviceElectric = [NSString stringWithFormat:@"%ld", self.bluetooth.equipment.battery];
    
    [dbOpration insertPeripheralInfo:bluetoothInfo];
    
    [dbOpration closeDataBase];
}

- (void)saveTreatInfo {
//    存储治疗数据到数据库
//    初始化数据库
    if (self.timeDuration - timeRemaining > 60 && _patientInfo.PatientID!=nil )  {
        dbOpration=[[DataBaseOpration alloc] init];
        if (treatInfoTmp) {
            NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
            treatInfoTmp.PatientID=_patientInfo.PatientID;
            
            [dateFormatter setDateFormat:@"yyyy-MM-dd"];
            treatInfoTmp.Date=[dateFormatter stringFromDate:beginDate];
            
            treatInfoTmp.Strength = [NSString stringWithFormat:@"%ld",(long)intensityLevel];
            treatInfoTmp.Frequency = [FrequencySelectors[_frequencySelector] stringByReplacingOccurrencesOfString:@"Hz" withString:@""];
            treatInfoTmp.Time = TimeSelectorsInteger[_timeSelector];
            
            [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
            treatInfoTmp.BeginTime = [dateFormatter stringFromDate:beginDate];
            treatInfoTmp.EndTime = @"";
            
            treatInfoTmp.CureTime = [NSString stringWithFormat:@"%.ld", (self.timeDuration - timeRemaining)/60];
            //更新
            [dbOpration updateTreatInfo:treatInfoTmp];
            [dbOpration closeDataBase];
        }
        else {
            treatInfoTmp=[[TreatInfo alloc] init];
            
            NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
            treatInfoTmp.PatientID=_patientInfo.PatientID;
            
            [dateFormatter setDateFormat:@"yyyy-MM-dd"];
            treatInfoTmp.Date=[dateFormatter stringFromDate:beginDate];
            
            treatInfoTmp.Strength = [NSString stringWithFormat:@"%ld",(long)intensityLevel];
            treatInfoTmp.Frequency = [FrequencySelectors[_frequencySelector] stringByReplacingOccurrencesOfString:@"Hz" withString:@""];
            treatInfoTmp.Time = TimeSelectorsInteger[_timeSelector];
            
            [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
            treatInfoTmp.BeginTime = [dateFormatter stringFromDate:beginDate];
            treatInfoTmp.EndTime = [dateFormatter stringFromDate:endDate];
            
            treatInfoTmp.CureTime = [NSString stringWithFormat:@"%.ld", (self.timeDuration - timeRemaining)/60];
            //插入
            [dbOpration insertTreatInfo:treatInfoTmp];
            [dbOpration closeDataBase];
        }
        
        NSNotification *notification = [NSNotification notificationWithName:@"SaveTreatInfo" object:nil userInfo:nil];
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    }
}

#pragma mark setter and getter
- (Bluetooth *)bluetooth {
    if (!_bluetooth) {
        _bluetooth = [Bluetooth shareBluetooth];
        _bluetooth.delegate = self;
        [_bluetooth scanEquipment];
        
    }
    return _bluetooth;
}

- (BluetoothInfo *)bluetoothInfo {
    //从数据库读取之前绑定设备
    _bluetoothInfo = nil;
    DataBaseOpration *dataBaseOpration = [[DataBaseOpration alloc] init];
    NSArray *bluetoothInfoArray=[dataBaseOpration getBluetoothDataFromDataBase];
        
    if (bluetoothInfoArray.count>0)
    {
        _bluetoothInfo = [bluetoothInfoArray objectAtIndex:0];
    }
    [dataBaseOpration closeDataBase];
    return _bluetoothInfo;
}

- (void)postBindDevice:(NSString *)deviceID {
    NSDictionary *jsonUserID = [NSDictionary dictionaryWithObjectsAndKeys:_patientInfo.PatientID,@"PatientID",deviceID,@"DeviceID",nil];
    NSArray *jsonArray=[NSArray arrayWithObjects:jsonUserID, nil];
    NSData *jsondata = [NSJSONSerialization dataWithJSONObject:jsonArray options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonString=[[NSString alloc] initWithData:jsondata encoding:NSUTF8StringEncoding];
    
    // 设置我们之后解析XML时用的关键字
    matchingElement = @"APP_SetPatientDeviceIDResponse";
    // 创建SOAP消息，内容格式就是网站上提示的请求报文的实体主体部分
    NSString *soapMsg = [NSString stringWithFormat:
                         @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
                         "<soap12:Envelope "
                         "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" "
                         "xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" "
                         "xmlns:soap12=\"http://schemas.xmlsoap.org/soap/envelope/\">"
                         "<soap12:Body>"
                         "<APP_SetPatientDeviceID xmlns=\"MeetingOnline\">"
                         "<JsonDeviceInfo>%@</JsonDeviceInfo>"
                         "</APP_SetPatientDeviceID>"
                         "</soap12:Body>"
                         "</soap12:Envelope>", jsonString,nil];
    //打印soapMsg信息
    NSLog(@"%@",soapMsg);
    
    //设置网络连接的url
    NSString *urlStr = [NSString stringWithFormat:@"%@",ADDRESS];
    NSURL *url = [NSURL URLWithString:urlStr];
    //设置request
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];
    NSString *msgLength=[NSString stringWithFormat:@"%lu",(long)[soapMsg length]];
    // 添加请求的详细信息，与请求报文前半部分的各字段对应
    [request addValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request addValue:msgLength forHTTPHeaderField:@"Content-Length"];
    // 设置请求行方法为POST，与请求报文第一行对应
    [request setHTTPMethod:@"POST"];//默认是GET
    // 将SOAP消息加到请求中
    [request setHTTPBody: [soapMsg dataUsingEncoding:NSUTF8StringEncoding]];
    // 创建连接
    conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (conn)
    {
        webData = [NSMutableData data];
    }
}

#pragma mark -
#pragma mark URL Connection Data Delegate Methods
// 刚开始接受响应时调用
-(void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *) response
{
    [webData setLength: 0];
}

// 每接收到一部分数据就追加到webData中
-(void) connection:(NSURLConnection *)connection didReceiveData:(NSData *) data
{
    [webData appendData:data];
}

// 出现错误时
-(void) connection:(NSURLConnection *)connection didFailWithError:(NSError *) error
{
    conn = nil;
    webData = nil;
}

// 完成接收数据时调用
-(void) connectionDidFinishLoading:(NSURLConnection *) connection
{
    NSString *theXML = [[NSString alloc] initWithBytes:[webData mutableBytes]
                                                length:[webData length]
                                              encoding:NSUTF8StringEncoding];
    
    // 打印出得到的XML
    NSLog(@"%@", theXML);
    // 使用NSXMLParser解析出我们想要的结果
    xmlParser = [[NSXMLParser alloc] initWithData: webData];
    [xmlParser setDelegate: self];
    [xmlParser setShouldResolveExternalEntities: YES];
    [xmlParser parse];
}


#pragma mark XML Parser Delegate Methods

// 开始解析一个元素名
-(void) parser:(NSXMLParser *) parser didStartElement:(NSString *) elementName namespaceURI:(NSString *) namespaceURI qualifiedName:(NSString *) qName attributes:(NSDictionary *) attributeDict
{
    if ([elementName isEqualToString:matchingElement])
    {
        if (!soapResults)
        {
            soapResults = [[NSMutableString alloc] init];
        }
        elementFound = YES;
    }
}

// 追加找到的元素值，一个元素值可能要分几次追加
-(void)parser:(NSXMLParser *) parser foundCharacters:(NSString *)string
{
    if (elementFound)
    {
        [soapResults appendString: string];
    }
}

// 结束解析这个元素名
-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:matchingElement])
    {
        elementFound = FALSE;
        // 强制放弃解析
        [xmlParser abortParsing];
    }
}

// 解析整个文件结束后
- (void)parserDidEndDocument:(NSXMLParser *)parser
{
    if (soapResults)
    {
        soapResults = nil;
    }
}

// 出错时，例如强制结束解析
- (void) parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    if (soapResults)
    {
        soapResults = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

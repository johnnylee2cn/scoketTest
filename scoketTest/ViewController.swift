//
//  ViewController.swift
//  scoketTest
//
//  Created by admin on 2017/8/20.
//  Copyright © 2017年 L. All rights reserved.
//

import UIKit


class ViewController: UIViewController {

    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var textView: UITextView!
    
    @IBAction func sendButton(_ sender: UIButton) {
        let content=textField.text!
        let message=["cmd":"msg","content":content]
        self.sendMessage(msgtosend: message)
        textField.text=nil
    }
    
    //socket服务端封装类对象
    var socketServer:MyTcpSocketServer?
    //socket客户端类对象
    var socketClient:TCPClient?

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //启动服务器
        socketServer = MyTcpSocketServer()
        socketServer?.start()
        
        processClientSocket()
    }

    //初始化客户端，并连接服务器
    func processClientSocket(){
        socketClient = TCPClient(addr: "localhost", port: 8080)
        
        DispatchQueue.global(qos: .background).async {
            //用于读取并解析服务端发来的消息
            func readmsg()->[String:Any]?{
                if let data = self.socketClient?.read(4){
                    if data.count == 4{
                        let ndata = NSData(bytes: data, length: data.count)
                        var length:Int32 = 0
                        ndata.getBytes(&length, length: data.count)
                        
                        if let buff = self.socketClient?.read(Int(length)){
                            let msgd = Data(bytes: buff, count: buff.count)
                            let msgi = try! JSONSerialization.jsonObject(with: msgd, options: .mutableContainers) as! [String:Any]
                            return msgi
                        }
                    }
                }
                return nil
            }
            
            //连接服务器
            let (success,msg)=self.socketClient!.connect(timeout: 5)
            if success{
                DispatchQueue.main.async {
                    self.alert(msg: "connect success", after: {
                    })
                }
                
            //发送用户名给服务器（这里使用随机生成）
            let msgtosend = ["cmd":"nickname","nickname":"游客:\(Int(arc4random()%1000))"]
            self.sendMessage(msgtosend: msgtosend)
                
                //不断接收服务器发来的消息
               while true{
                   if let msg=readmsg(){
                     DispatchQueue.main.async {
                        self.processMessage(msg: msg)
                         }
                        }else{
                       DispatchQueue.main.async {
                           //self.disconnect()
                            }
                     break
                      }
                    }
            }else{
                DispatchQueue.main.async {
                    self.alert(msg: msg,after: {
                    })
                }
            }
           
            
        }
    }
    
    //发送消息
    func sendMessage(msgtosend:[String:String]){
        let msgdata = try? JSONSerialization.data(withJSONObject: msgtosend, options: .prettyPrinted)
        var len:Int32 = Int32(msgdata!.count)
        let data = Data(bytes: &len, count: 4)
        self.socketClient?.send(data: data)
        self.socketClient?.send(data: msgdata!)
    }
    
    //处理服务器返回到消息
    func processMessage(msg:[String:Any]){
        let cmd:String = msg["cmd"] as! String
        switch(cmd){
            case "msg":
            self.textView.text = self.textView.text + (msg["from"] as! String) + ": " + (msg["content"] as! String) + "\n"
        default: break
            print(msg)
        }
    }
    
    //消息弹出框
    func alert(msg:String,after:()->(Void)){
        let alertController = UIAlertController(title: "",
                                                message: msg,
                                                preferredStyle: .alert)
        self.present(alertController, animated: true, completion: nil)
        
        //1.5秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5) {
            alertController.dismiss(animated: false, completion: nil)
        }
    }
    
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}


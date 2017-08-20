//
//  MyTcpSocketServer.swift
//  hangge_756
//
//  Created by hangge on 2016/11/21.
//  Copyright © 2016年 hangge. All rights reserved.
//

import UIKit

//服务器端口
var serverport = 8080

//客户端管理类（便于服务端管理所有连接的客户端）
class ChatUser:NSObject{
    var tcpClient:TCPClient?
    var username:String=""
    var socketServer:MyTcpSocketServer?
    
    //解析收到的消息
    func readMsg()->[String:Any]?{
        //read 4 byte int as type
        if let data=self.tcpClient!.read(4){
            if data.count==4{
                let ndata=NSData(bytes: data, length: data.count)
                var len:Int32=0
                ndata.getBytes(&len, length: data.count)
                if let buff=self.tcpClient!.read(Int(len)){
                    
                    let msgd = Data(bytes: buff, count: buff.count)
                    let msgi = (try! JSONSerialization.jsonObject(with: msgd,
                                options: .mutableContainers)) as! [String:Any]
                    return msgi
                }
            }
        }
        return nil
    }
    
    //循环接收消息
    func messageloop(){
        while true{
            if let msg=self.readMsg(){
                self.processMsg(msg: msg)
            }else{
                self.removeme()
                break
            }
        }
    }
    
    //处理收到的消息
    func processMsg(msg:[String:Any]){
        if msg["cmd"] as! String=="nickname"{
            self.username=msg["nickname"] as! String
        }
        self.socketServer!.processUserMsg(user: self, msg: msg)
    }
    
    //发送消息
    func sendMsg(msg:[String:Any]){
        let jsondata=try? JSONSerialization.data(withJSONObject: msg, options:
            JSONSerialization.WritingOptions.prettyPrinted)
        var len:Int32=Int32(jsondata!.count)
        
        let data = Data(bytes: &len, count: 4)
        _ = self.tcpClient!.send(data: data)
        _ = self.tcpClient!.send(data: jsondata!)
    }
    
    //移除该客户端
    func removeme(){
        self.socketServer!.removeUser(u: self)
    }
    
    //关闭连接
    func kill(){
        _ = self.tcpClient!.close()
    }
}

//服务端类
class MyTcpSocketServer: NSObject {
    var clients:[ChatUser]=[]
    var server:TCPServer=TCPServer(addr: "127.0.0.1", port: serverport)
    var serverRuning:Bool=false
    
    //启动服务
    func start() {
        _ = server.listen()
        self.serverRuning=true
        
        DispatchQueue.global(qos: .background).async {
            while self.serverRuning{
                let client=self.server.accept()
                if let c=client{
                    DispatchQueue.global(qos: .background).async {
                        self.handleClient(c: c)
                    }
                }
            }
        }

        self.log(msg: "server started...")
    }
    
    //停止服务
    func stop() {
        self.serverRuning=false
        _ = self.server.close()
        //forth close all client socket
        for c:ChatUser in self.clients{
            c.kill()
        }
        self.log(msg: "server stoped...")
    }
    
    //处理连接的客户端
    func handleClient(c:TCPClient){
        self.log(msg: "new client from:"+c.addr)
        let u=ChatUser()
        u.tcpClient=c
        clients.append(u)
        u.socketServer=self
        u.messageloop()
    }
    
    //处理各消息命令
    func processUserMsg(user:ChatUser, msg:[String:Any]){
        self.log(msg: "\(user.username)[\(user.tcpClient!.addr)]cmd:"+(msg["cmd"] as! String))
        //boardcast message
        var msgtosend=[String:String]()
        let cmd = msg["cmd"] as! String
        if cmd=="nickname"{
            msgtosend["cmd"]="join"
            msgtosend["nickname"]=user.username
            msgtosend["addr"]=user.tcpClient!.addr
        }else if(cmd=="msg"){
            msgtosend["cmd"]="msg"
            msgtosend["from"]=user.username
            msgtosend["content"]=(msg["content"] as! String)
        }else if(cmd=="leave"){
            msgtosend["cmd"]="leave"
            msgtosend["nickname"]=user.username
            msgtosend["addr"]=user.tcpClient!.addr
        }
        for user:ChatUser in self.clients{
            //if u~=user{
            user.sendMsg(msg: msgtosend)
            //}
        }
    }
    
    //移除用户
    func removeUser(u:ChatUser){
        self.log(msg: "remove user\(u.tcpClient!.addr)")
        if let possibleIndex=self.clients.index(of: u){
            self.clients.remove(at: possibleIndex)
            self.processUserMsg(user: u, msg: ["cmd":"leave"])
        }
    }
    
    //日志打印
    func log(msg:String){
        print(msg)
    }
}

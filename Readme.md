##What is this

The sample app debuggery is meant to show how to use ESDebugConsole, but it's also pretty handy to keep on your phone as a way to email yourself device logs.

##Get the code

git clone https://github.com/EverythingSolution/Debuggery.git

cd Debuggery

git submodule update --init

##Use the code

ESDebugConsole is the core functionality. You embed this in your app and somewhere in startup after you've made your window and root view controller, call the singleton to initialize it.
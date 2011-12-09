##Get the code

git clone https://github.com/EverythingSolution/Debuggery.git

cd Debuggery

git submodule init

git submodule update

##Use the code

ESDebugConsole is the core functionality. You embed this in your app and somewhere in startup after you've made your window and root view controller, call the singleton to initialize it.

You call up the console with a rotation gesture that it attached to the window, but you can replace the gesture recognizer with one that suits you better or move the existing one to a view that's better for your apps implementation.
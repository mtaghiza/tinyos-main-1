#include <SaleaeDeviceApi.h>

#include <memory>
#include <iostream>
#include <string>

#include <queue>
#include <mutex>
#include <thread>

#include <fstream>
#include <time.h>

void __stdcall OnConnect( U64 device_id, GenericInterface* device_interface, void* user_data );
void __stdcall OnDisconnect( U64 device_id, void* user_data );
void __stdcall OnReadData( U64 device_id, U8* data, U32 data_length, void* user_data );
void __stdcall OnWriteData( U64 device_id, U8* data, U32 data_length, void* user_data );
void __stdcall OnError( U64 device_id, void* user_data );

#define USE_LOGIC_16 0

#if( USE_LOGIC_16 )
	Logic16Interface* gDeviceInterface = NULL;
#else
	LogicInterface* gDeviceInterface = NULL;
#endif

U64 gLogicId = 0;
U32 gSampleRateHz = 4000000;

std::mutex m;
std::condition_variable cv;
std::queue<U8*> dataQueue;
std::queue<U32> lenQueue;
bool terminate = false;

void logWorker(std::string filename){
  std::ofstream of;
  of.open(filename);
  int writeCount = 0;
  U8 last = 0;
  long long int ticks = 0;
  int write_notify = 1000;
  of << "# " << std::dec << time(NULL) << std::endl;
  while (!terminate){
    if (0 == (writeCount % write_notify)){
      std::cout << "Elapsed(s): " << ticks/4000000 << std::endl;
    }
    std::unique_lock<std::mutex> lock(m);
    cv.wait(lock);
    while (! dataQueue.empty()){
      U8* data = dataQueue.front();
      U32 data_length = lenQueue.front();

//	  std::cout << writeCount << " Read " << data_length << " bytes, starting with 0x" << std::hex << (int)*data << std::dec << std::endl;
//      of << writeCount << " Read " << data_length << std::endl;
      for (U32 k = 0; k < data_length; k++){
        if (data[k] != last){
          of << ticks << " " << std::hex << (int)data[k] << std::dec << std::endl;
          last = data[k];
        }
        ticks++;
      }

      //free the buffer.
	  DevicesManagerInterface::DeleteU8ArrayPtr( data );
      dataQueue.pop();
      lenQueue.pop();
      writeCount++;
    }
  }
  of.close();
}

int main( int argc, char *argv[] )
{
	DevicesManagerInterface::RegisterOnConnect( &OnConnect );
	DevicesManagerInterface::RegisterOnDisconnect( &OnDisconnect );
	DevicesManagerInterface::BeginConnect();

	std::cout << std::uppercase << "Devices are currently set up to read and write at " << gSampleRateHz << " Hz.  You can change this in the code." << std::endl;
    if (argc == 3){
      int timeout = atoi(argv[1]);
      int timeout_unit = 5;
      std::string filename = argv[2];
      //Start up the worker thread.
      std::thread thr(logWorker, filename);
      for (int k = 0; k < timeout/timeout_unit && !terminate; k++){
        sleep(timeout_unit);
//        std::cout << (1+k)*timeout_unit << " / "<< timeout << std::endl;
      }
      terminate = true;
      thr.join();
  	  return 0;
    }else{
      std::cerr << "Usage: " << argv[0] << " <timeout (s)> <outputFile>" << std::endl;
      return 1;
    }
}

void __stdcall OnConnect( U64 device_id, GenericInterface* device_interface, void* user_data )
{
#if( USE_LOGIC_16 )

	if( dynamic_cast<Logic16Interface*>( device_interface ) != NULL )
	{
		std::cout << "A Logic16 device was connected (id=0x" << std::hex << device_id << std::dec << ")." << std::endl;

		gDeviceInterface = (Logic16Interface*)device_interface;
		gLogicId = device_id;

		gDeviceInterface->RegisterOnReadData( &OnReadData );
		gDeviceInterface->RegisterOnWriteData( &OnWriteData );
		gDeviceInterface->RegisterOnError( &OnError );

		U32 channels[16];
		for( U32 i=0; i<16; i++ )
			channels[i] = i;

		gDeviceInterface->SetActiveChannels( channels, 16 );
		gDeviceInterface->SetSampleRateHz( gSampleRateHz );
	}

#else

	if( dynamic_cast<LogicInterface*>( device_interface ) != NULL )
	{
		std::cout << "A Logic device was connected (id=0x" << std::hex << device_id << std::dec << ")." << std::endl;

		gDeviceInterface = (LogicInterface*)device_interface;
		gLogicId = device_id;

		gDeviceInterface->RegisterOnReadData( &OnReadData );
		gDeviceInterface->RegisterOnWriteData( &OnWriteData );
		gDeviceInterface->RegisterOnError( &OnError );

		gDeviceInterface->SetSampleRateHz( gSampleRateHz );
        gDeviceInterface->ReadStart();
	}

#endif
}

void __stdcall OnDisconnect( U64 device_id, void* user_data )
{
	if( device_id == gLogicId )
	{
		std::cout << "A device was disconnected (id=0x" << std::hex << device_id << std::dec << ")." << std::endl;
		gDeviceInterface = NULL;
	}
}

void __stdcall OnReadData( U64 device_id, U8* data, U32 data_length, void* user_data )
{
  std::unique_lock<std::mutex> lock(m);
  dataQueue.push(data);
  lenQueue.push(data_length);
  cv.notify_one();
//#if( USE_LOGIC_16 )
//	std::cout << "Read " << data_length/2 << " words, starting with 0x" << std::hex << *(U16*)data << std::dec << std::endl;
//#else
//	std::cout << "Read " << data_length << " bytes, starting with 0x" << std::hex << (int)*data << std::dec << std::endl;
//#endif
//
//	//you own this data.  You don't have to delete it immediately, you could keep it and process it later, for example, or pass it to another thread for processing.
//	DevicesManagerInterface::DeleteU8ArrayPtr( data );
}

void __stdcall OnWriteData( U64 device_id, U8* data, U32 data_length, void* user_data )
{
#if( USE_LOGIC_16 )

#else
	static U8 dat = 0;

	//it's our job to feed data to Logic whenever this function gets called.  Here we're just counting.
	//Note that you probably won't be able to get Logic to write data at faster than 4MHz (on Windows) do to some driver limitations.

	//here we're just filling the data with a 0-255 pattern.
	for( U32 i=0; i<data_length; i++ )
	{
		*data = dat;
		dat++;
		data++;
	}

	std::cout << "Wrote " << data_length << " bytes of data." << std::endl;
#endif
}

void __stdcall OnError( U64 device_id, void* user_data )
{
	std::cout << "A device reported an Error.  This probably means that it could not keep up at the given data rate, or was disconnected. You can re-start the capture automatically, if your application can tolerate gaps in the data." << std::endl;
    terminate = true;
	//note that you should not attempt to restart data collection from this function -- you'll need to do it from your main thread (or at least not the one that just called this function).
}

/*-----------------------------------------------------------------------*/
/* Low level disk I/O module skeleton for Petit FatFs (C)ChaN, 2009      */
/*-----------------------------------------------------------------------*/

#include "diskio.h"
#warning diskio.c return values not used


/*-----------------------------------------------------------------------*/
/* Initialize Disk Drive                                                 */
/*-----------------------------------------------------------------------*/

DSTATUS disk_initialize (
	BYTE Drive           /* Physical drive number */
)
{
	DSTATUS stat = RES_OK;

	// Put your code here
//	call StdOut.print("initialize: ");
//	call StdOut.printBase10uint8(Drive);
//	call StdOut.print("\n\r");

	return stat;
}


/*-----------------------------------------------------------------------*/
/* Return Current Disk Status                                            */
/*-----------------------------------------------------------------------*/

DSTATUS disk_status (
  BYTE Drive     /* Physical drive number */
)
{
//	DSTATUS stat;

//	call StdOut.print("status: ");
//	call StdOut.printBase10uint8(Drive);
//	call StdOut.print("\n\r");

//	return stat;
	return 0;
}

/*-----------------------------------------------------------------------*/
/* Read Partial Sector                                                   */
/*-----------------------------------------------------------------------*/

DRESULT disk_read (
  BYTE Drive,          /* Physical drive number */
  BYTE* Buffer,        /* Pointer to the read data buffer */
  DWORD SectorNumber,  /* Start sector number */
  BYTE SectorCount     /* Number of sectros to read */
)
{
	DRESULT res = RES_OK;

	// Put your code here
//	call StdOut.print("read: ");
//	call StdOut.printBase10uint16(SectorNumber);
//	call StdOut.print(" ");
//	call StdOut.printBase10uint16(SectorCount);
//	call StdOut.print("\n\r");
//

	call SDCard.read(SectorNumber*512, Buffer, SectorCount*512);

	return res;
}



/*-----------------------------------------------------------------------*/
/* Write Sector                                                          */
/*-----------------------------------------------------------------------*/

DRESULT disk_write (
  BYTE Drive,          /* Physical drive number */
  const BYTE* Buffer,  /* Pointer to the write data (may be non aligned) */
  DWORD SectorNumber,  /* Sector number to write */
  BYTE SectorCount     /* Number of sectors to write */
)
{
	uint16_t i;
	DRESULT res = RES_OK;

//	call StdOut.print("write: ");
//	call StdOut.printBase10uint16(SectorNumber);
//	call StdOut.print(" ");
//	call StdOut.printBase10uint16(SectorCount);
//	call StdOut.print("\n\r");

	for (i = 0; i < SectorCount; i++)
		call SDCard.write(SectorNumber*512, (uint8_t*)Buffer+512*i, 512);

	return res;
}



/*-----------------------------------------------------------------------*/
/* Device Specific Features and Miscellaneous Functions                  */
/*-----------------------------------------------------------------------*/

DRESULT disk_ioctl (
  BYTE Drive,      /* Drive number */
  BYTE Command,    /* Control command code */
  void* Buffer     /* Parameter and data buffer */
)
{
	DRESULT res = RES_OK;


	switch(Command)
	{
		// Make sure that the disk drive has finished pending write process.
		// When the disk I/O module has a write back cache, flush the dirty
		// sector immediately. This command is not used in read-only configuration.
		case CTRL_SYNC:
//						call StdOut.print("ioctl: sync\n\r");
						break;

		// Returns sector size of the drive into the WORD variable pointed by Buffer.
		// This command is not used in fixed sector size configuration, _MAX_SS is 512.
		case GET_SECTOR_SIZE:
//						call StdOut.print("ioctl: get sector size\n\r");
						break;

		// Returns number of available sectors on the drive into the DWORD variable
		// pointed by Buffer. This command is used by only f_mkfs function to
		// determine the volume size to be created.
		case GET_SECTOR_COUNT:
//						call StdOut.print("ioctl: get sector count\n\r");
						break;

		// Returns erase block size of the flash memory in unit of sector into the
		// DWORD variable pointed by Buffer. The allowable value is 1 to 32768 in
		// power of 2. Return 1 if the erase block size is unknown or disk devices.
		// This command is used by only f_mkfs function and it attempts to align data
		// area to the erase block boundary.
		case GET_BLOCK_SIZE:
//						call StdOut.print("ioctl: get block size\n\r");
						break;


		// Erases a part of the flash memory specified by a DWORD array
		// {<start sector>, <end sector>} pointed by Buffer. When this feature
		// is not supported or not a flash memory media, this command has no
		// effect. The FatFs does not check the result code and the file function
		// is not affected even if the sectors are not erased well. This command
		// is called on removing a cluster chain when _USE_ERASE is 1.
		case CTRL_ERASE_SECTOR:
//						call StdOut.print("ioctl: erase sector\n\r");
						break;

		default:
					break;
	}


	return res;
}

/*-----------------------------------------------------------------------*/
/* Get Current Time                                                      */
/*-----------------------------------------------------------------------*/

DWORD get_fattime (void)
{
//	call StdOut.print("get fattime\n\r");

	return 42;
}




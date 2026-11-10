/* Cardnull OS — the bootloader's own UEFI declarations.
 *
 * Part of milestone 22: our own bootloader, replacing GRUB
 * behind the UEFI door. The loader is a UEFI application, and
 * C for that target wants declarations for the firmware's
 * tables and protocols. The usual sets of those declarations
 * travel under licenses we do not borrow from; the firmware's
 * interface itself is a published, stable set of structures,
 * small enough to write down by hand — so here it is, written
 * down by hand, from the UEFI specification's own layout, and
 * public domain like everything else in this tree.
 *
 * Only what the loader speaks is declared in full. The boot
 * services table is laid out in its whole order regardless —
 * a function pointer's meaning is its place in the table, and
 * a short table would put every later place wrong. Fields the
 * loader never calls are carried as plain pointers, present
 * so the ones it does call stand where the firmware put them.
 *
 * Written by hand, in the open, in the public domain.
 */

#ifndef CARDNULL_EFI_H
#define CARDNULL_EFI_H

#include <stdint.h>
#include <stddef.h>

/* The firmware's own word sizes on x86-64: a status, a count,
 * and a physical address are each eight bytes. */
typedef uint64_t EFI_STATUS;
typedef uint64_t UINTN;
typedef uint64_t EFI_PHYSICAL_ADDRESS;
typedef void *EFI_HANDLE;
typedef uint16_t CHAR16;

#define EFI_SUCCESS 0
#define EFI_ERROR_BIT (1ULL << 63)
#define EFI_ERROR(status) (((int64_t)(status)) < 0)

/* Status codes the loader may report by number when a road
 * fails, named so the printing reads in words first. */
#define EFI_UNSUPPORTED ((EFI_STATUS)(EFI_ERROR_BIT | 3))
#define EFI_BUFFER_TOO_SMALL ((EFI_STATUS)(EFI_ERROR_BIT | 5))
#define EFI_OUT_OF_RESOURCES ((EFI_STATUS)(EFI_ERROR_BIT | 9))
#define EFI_NOT_FOUND ((EFI_STATUS)(EFI_ERROR_BIT | 14))
#define EFI_ACCESS_DENIED ((EFI_STATUS)(EFI_ERROR_BIT | 15))

/* A global unique identifier, in the firmware's mixed-endian
 * keeping: the first three fields little-endian, the last
 * eight bytes as written. */
typedef struct {
    uint32_t Data1;
    uint16_t Data2;
    uint16_t Data3;
    uint8_t Data4[8];
} EFI_GUID;

/* Every firmware table opens with this header. */
typedef struct {
    uint64_t Signature;
    uint32_t Revision;
    uint32_t HeaderSize;
    uint32_t CRC32;
    uint32_t Reserved;
} EFI_TABLE_HEADER;

/* One row of the firmware's memory map: what stands at a
 * physical address, how much of it there is, and its kind. */
typedef struct {
    uint32_t Type;
    EFI_PHYSICAL_ADDRESS PhysicalStart;
    uint64_t VirtualStart;
    uint64_t NumberOfPages;
    uint64_t Attribute;
} EFI_MEMORY_DESCRIPTOR;

/* The kinds of memory, as the firmware numbers them. */
enum {
    EfiReservedMemoryType = 0,
    EfiLoaderCode = 1,
    EfiLoaderData = 2,
    EfiBootServicesCode = 3,
    EfiBootServicesData = 4,
    EfiRuntimeServicesCode = 5,
    EfiRuntimeServicesData = 6,
    EfiConventionalMemory = 7,
    EfiUnusableMemory = 8,
    EfiACPIReclaimMemory = 9,
    EfiACPIMemoryNVS = 10,
    EfiMemoryMappedIO = 11,
    EfiMemoryMappedIOPortSpace = 12,
    EfiPalCode = 13,
    EfiPersistentMemory = 14,
    EfiUnacceptedMemoryType = 15
};

/* How pages are asked for: anywhere, under a ceiling, or at
 * one exact address — the kernel's ground is the third. */
enum {
    AllocateAnyPages = 0,
    AllocateMaxAddress = 1,
    AllocateAddress = 2
};

/* Where pool memory's ownership is charged; the loader's
 * readings are charged to the loader, as they should be. */
enum { EfiLoaderDataPool = 2 };

typedef EFI_STATUS (*EFI_ALLOCATE_PAGES)(uint32_t Type,
                                         uint32_t MemoryType,
                                         UINTN Pages,
                                         EFI_PHYSICAL_ADDRESS *Memory);
typedef EFI_STATUS (*EFI_FREE_PAGES)(EFI_PHYSICAL_ADDRESS Memory,
                                     UINTN Pages);
typedef EFI_STATUS (*EFI_GET_MEMORY_MAP)(UINTN *MemoryMapSize,
                                         EFI_MEMORY_DESCRIPTOR *MemoryMap,
                                         UINTN *MapKey,
                                         UINTN *DescriptorSize,
                                         uint32_t *DescriptorVersion);
typedef EFI_STATUS (*EFI_ALLOCATE_POOL)(uint32_t PoolType, UINTN Size,
                                        void **Buffer);
typedef EFI_STATUS (*EFI_FREE_POOL)(void *Buffer);
typedef EFI_STATUS (*EFI_HANDLE_PROTOCOL)(EFI_HANDLE Handle,
                                          const EFI_GUID *Protocol,
                                          void **Interface);
typedef EFI_STATUS (*EFI_LOCATE_PROTOCOL)(const EFI_GUID *Protocol,
                                          void *Registration,
                                          void **Interface);
typedef EFI_STATUS (*EFI_EXIT_BOOT_SERVICES)(EFI_HANDLE ImageHandle,
                                             UINTN MapKey);
typedef EFI_STATUS (*EFI_SET_WATCHDOG_TIMER)(uint64_t Timeout,
                                             uint64_t WatchdogCode,
                                             UINTN DataSize,
                                             CHAR16 *WatchdogData);

/* The boot services table, in its whole order. The loader
 * calls AllocatePages, GetMemoryMap, AllocatePool, FreePool,
 * HandleProtocol, LocateProtocol, SetWatchdogTimer, and
 * ExitBootServices; the rest stand in their places. */
typedef struct {
    EFI_TABLE_HEADER Hdr;
    void *RaiseTPL;
    void *RestoreTPL;
    EFI_ALLOCATE_PAGES AllocatePages;
    EFI_FREE_PAGES FreePages;
    EFI_GET_MEMORY_MAP GetMemoryMap;
    EFI_ALLOCATE_POOL AllocatePool;
    EFI_FREE_POOL FreePool;
    void *CreateEvent;
    void *SetTimer;
    void *WaitForEvent;
    void *SignalEvent;
    void *CloseEvent;
    void *CheckEvent;
    void *InstallProtocolInterface;
    void *ReinstallProtocolInterface;
    void *UninstallProtocolInterface;
    EFI_HANDLE_PROTOCOL HandleProtocol;
    void *Reserved;
    void *RegisterProtocolNotify;
    void *LocateHandle;
    void *LocateDevicePath;
    void *InstallConfigurationTable;
    void *LoadImage;
    void *StartImage;
    void *Exit;
    void *UnloadImage;
    EFI_EXIT_BOOT_SERVICES ExitBootServices;
    void *GetNextMonotonicCount;
    void *Stall;
    EFI_SET_WATCHDOG_TIMER SetWatchdogTimer;
    void *ConnectController;
    void *DisconnectController;
    void *OpenProtocol;
    void *CloseProtocol;
    void *OpenProtocolInformation;
    void *ProtocolsPerHandle;
    void *LocateHandleBuffer;
    EFI_LOCATE_PROTOCOL LocateProtocol;
    void *InstallMultipleProtocolInterfaces;
    void *UninstallMultipleProtocolInterfaces;
    void *CalculateCrc32;
    void *CopyMem;
    void *SetMem;
    void *CreateEventEx;
} EFI_BOOT_SERVICES;

/* The firmware's text-out door: the loader's only voice
 * until the kernel takes the screen. */
typedef struct EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
    void *Reset;
    EFI_STATUS (*OutputString)(
        struct EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *This,
        const CHAR16 *String);
    void *TestString;
    void *QueryMode;
    void *SetMode;
    void *SetAttribute;
    void *ClearScreen;
    void *SetCursorPosition;
    void *EnableCursor;
    void *Mode;
} EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;

/* The system table: where boot services and the console
 * are found. */
typedef struct {
    EFI_TABLE_HEADER Hdr;
    CHAR16 *FirmwareVendor;
    uint32_t FirmwareRevision;
    EFI_HANDLE ConsoleInHandle;
    void *ConIn;
    EFI_HANDLE ConsoleOutHandle;
    EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *ConOut;
    EFI_HANDLE StandardErrorHandle;
    void *StdErr;
    void *RuntimeServices;
    EFI_BOOT_SERVICES *BootServices;
    UINTN NumberOfTableEntries;
    void *ConfigurationTable;
} EFI_SYSTEM_TABLE;

/* How this loader itself was loaded: its device is the door
 * to the boot volume it must read the kernel from. */
typedef struct {
    uint32_t Revision;
    EFI_HANDLE ParentHandle;
    EFI_SYSTEM_TABLE *SystemTable;
    EFI_HANDLE DeviceHandle;
    void *FilePath;
    void *Reserved;
    uint32_t LoadOptionsSize;
    void *LoadOptions;
    void *ImageBase;
    uint64_t ImageSize;
    uint32_t ImageCodeType;
    uint32_t ImageDataType;
    void *Unload;
} EFI_LOADED_IMAGE_PROTOCOL;

/* A file on a firmware volume. The loader reads the kernel
 * through this, and learns its size by standing at its end. */
typedef struct EFI_FILE_PROTOCOL {
    uint64_t Revision;
    EFI_STATUS (*Open)(struct EFI_FILE_PROTOCOL *This,
                       struct EFI_FILE_PROTOCOL **NewHandle,
                       CHAR16 *FileName, uint64_t OpenMode,
                       uint64_t Attributes);
    EFI_STATUS (*Close)(struct EFI_FILE_PROTOCOL *This);
    void *Delete;
    EFI_STATUS (*Read)(struct EFI_FILE_PROTOCOL *This,
                       UINTN *BufferSize, void *Buffer);
    void *Write;
    EFI_STATUS (*GetPosition)(struct EFI_FILE_PROTOCOL *This,
                              uint64_t *Position);
    EFI_STATUS (*SetPosition)(struct EFI_FILE_PROTOCOL *This,
                              uint64_t Position);
    void *GetInfo;
    void *SetInfo;
    void *Flush;
    void *OpenEx;
    void *ReadEx;
    void *WriteEx;
    void *FlushEx;
} EFI_FILE_PROTOCOL;

#define EFI_FILE_MODE_READ 1ULL
#define EFI_FILE_POSITION_END 0xFFFFFFFFFFFFFFFFULL

/* A whole volume's filesystem: one open door, to its root. */
typedef struct EFI_SIMPLE_FILE_SYSTEM_PROTOCOL {
    uint64_t Revision;
    EFI_STATUS (*OpenVolume)(
        struct EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *This,
        EFI_FILE_PROTOCOL **Root);
} EFI_SIMPLE_FILE_SYSTEM_PROTOCOL;

/* The graphics protocol: how the loader chooses the screen
 * the kernel will draw on, and learns where its pixels live. */
typedef struct {
    uint32_t RedMask;
    uint32_t GreenMask;
    uint32_t BlueMask;
    uint32_t ReservedMask;
} EFI_PIXEL_BITMASK;

enum {
    PixelRedGreenBlueReserved8BitPerColor = 0,
    PixelBlueGreenRedReserved8BitPerColor = 1,
    PixelBitMask = 2,
    PixelBltOnly = 3
};

typedef struct {
    uint32_t Version;
    uint32_t HorizontalResolution;
    uint32_t VerticalResolution;
    uint32_t PixelFormat;
    EFI_PIXEL_BITMASK PixelInformation;
    uint32_t PixelsPerScanLine;
} EFI_GRAPHICS_OUTPUT_MODE_INFORMATION;

typedef struct {
    uint32_t MaxMode;
    uint32_t Mode;
    EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *Info;
    UINTN SizeOfInfo;
    EFI_PHYSICAL_ADDRESS FrameBufferBase;
    UINTN FrameBufferSize;
} EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE;

typedef struct EFI_GRAPHICS_OUTPUT_PROTOCOL {
    EFI_STATUS (*QueryMode)(struct EFI_GRAPHICS_OUTPUT_PROTOCOL *This,
                            uint32_t ModeNumber, UINTN *SizeOfInfo,
                            EFI_GRAPHICS_OUTPUT_MODE_INFORMATION **Info);
    EFI_STATUS (*SetMode)(struct EFI_GRAPHICS_OUTPUT_PROTOCOL *This,
                          uint32_t ModeNumber);
    void *Blt;
    EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE *Mode;
} EFI_GRAPHICS_OUTPUT_PROTOCOL;

#endif /* CARDNULL_EFI_H */

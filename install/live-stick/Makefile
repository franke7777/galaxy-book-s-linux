obj-m := ufshcd-pci.o
all:
	$(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(CURDIR) modules

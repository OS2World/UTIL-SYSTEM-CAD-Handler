unit cadh;

interface

const
  cadh_drivername                               ='\DEV\CADH$$$$';
  cadh_ioctl_category                           =$80;

  cadh_ioctl_register_eventsem                  =$00;
  cadh_ioctl_deregister_eventsem                =$01;
  cadh_ioctl_register_eventsem_enhanced         =$02;
  cadh_ioctl_deregister_eventsem_enhanced       =$03;
  cadh_ioctl_modify_priority                    =$04; // not functional
  cadh_ioctl_kill_proc                          =$05; // like xf86sup.sys
  cadh_ioctl_setsesmgrhotkey                    =$06; // like kbdbase.sys

type
  register_eventsem_param       =
    packed record
      Sem                       :Longint;
      Event                     :Byte;          // enhanced only
      Event_Mask                :Byte;          // ..
      Argument                  :SmallWord;
      Argument_Mask             :SmallWord;
    end;

implementation

end.

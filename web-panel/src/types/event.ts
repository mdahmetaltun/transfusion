export type EventType =
  | 'caseCreated'
  | 'mtpActivated'
  | 'mtpDeactivated'
  | 'productAdded'
  | 'productReceived'
  | 'productAdministered'
  | 'productReturned'
  | 'productWasted'
  | 'lethalTriadRecorded'
  | 'caseClosed'
  | 'note'
  | string;

export interface Event {
  id: string;
  type: EventType;
  timestamp?: string;
  payload?: Record<string, any>;
}

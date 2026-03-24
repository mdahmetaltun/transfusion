export type ProductStatus = 'registered' | 'received' | 'administered' | 'returned' | 'wasted';
export type ProductType = 'ES' | 'TDP' | 'TSP' | 'KRIYO' | string;

export interface BloodProductUnit {
  id: string;
  caseId?: string;
  productType: ProductType;
  barcode?: string;
  lotNumber?: string;
  expiryDate?: string;
  bloodGroup?: string;
  rhFactor?: string;
  dispatchedBy?: string;
  status: ProductStatus;
  registeredAt?: string;
  receivedAt?: string;
  administeredAt?: string;
  notes?: string;
}

export const workspaceSections=['overview','spreads','assets','characters','environments','tasks','reviews','approvals','decisions','activity','reports','settings'] as const;
export type WorkspaceSection=typeof workspaceSections[number];
export const sectionLabels:Record<WorkspaceSection,string>={overview:'Overview',spreads:'Spreads',assets:'Assets',characters:'Characters',environments:'Environments',tasks:'Tasks',reviews:'Reviews',approvals:'Approvals',decisions:'Decisions',activity:'Activity',reports:'Reports',settings:'Settings'};

import {PageHeader} from '@/components/layout/Page';
import {PermissionMatrix} from '@/components/rbac/PermissionMatrix';
import {RoleCreator} from '@/components/rbac/RoleCreator';

export default function RolesPage(){
  return <div>
    <PageHeader title="Roles & permissions" description="Manage organisation authorization through roles and auditable permission grants."/>
    <RoleCreator/>
    <PermissionMatrix/>
  </div>
}

package common

import (
	"encoding/json"
	"fmt"
	"os"
	"path"
	"path/filepath"

	"github.com/spf13/pflag"
	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/pkg/providers"
	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/pkg/tfvars"
	"sigs.k8s.io/provider-ibmcloud-test-infra/kubetest2-tf/pkg/utils"

	bootstraputil "k8s.io/cluster-bootstrap/token/util"
)

const (
	Name = "common"
)

var _ providers.Provider = &Provider{}

var CommonProvider = &Provider{}

type Provider struct {
	tfvars.TFVars
}

func (p *Provider) BindFlags(flags *pflag.FlagSet) {
	flags.StringVar(
		&p.ReleaseMarker, "release-marker", "ci/latest", "Kubernetes Release Marker",
	)
	flags.StringVar(
		&p.BuildVersion, "build-version", "", "Kubernetes Build Version",
	)
	flags.StringVar(
		&p.Runtime, "runtime", "containerd", "Runtime used while installing k8s cluster",
	)
	flags.StringVar(
		&p.StorageServer, "s3-server", "", "S3 server where Kubernetes Bits are stored",
	)
	flags.StringVar(
		&p.StorageBucket, "bucket", "", "Storage Bucket",
	)
	flags.StringVar(
		&p.StorageDir, "directory", "", "Storage Directory",
	)
	flags.StringVar(
		&p.ClusterName, "cluster-name", "", "Kubernetes Cluster Name, this will used for creating the nodes and directories etc(Default: autogenerated with k8s-cluster-<6letters>",
	)
	flags.IntVar(
		&p.ApiServerPort, "apiserver-port", 992, "API Server Port Address",
	)
	flags.IntVar(
		&p.WorkersCount, "workers-count", 0, "Numbers of workers in the k8s cluster",
	)
	flags.StringVar(
		&p.BootstrapToken, "bootstrap-token", "", "Kubeadm bootstrap token used for installing and joining the cluster(default: random generated token in [a-z0-9]{6}\\.[a-z0-9]{16} format)",
	)
	flags.StringVar(
		&p.KubeconfigPath, "kubeconfig-path", "", "File path to write the kubeconfig content for the deployed cluster(default: data folder where terraform files copied)",
	)
	flags.StringVar(
		&p.SSHPrivateKey, "ssh-private-key", "~/.ssh/id_rsa", "SSH Private Key file's complete path to login to the deployed vms",
	)
	flags.BoolVar(
		&p.IgnoreDestroy, "ignore-destroy-errors", false, "Ignore errors during the destroy if any",
	)
}

func (p *Provider) DumpConfig(dir string) error {
	filename := path.Join(dir, Name+".auto.tfvars.json")

	config, err := json.MarshalIndent(p.TFVars, "", "  ")
	if err != nil {
		return fmt.Errorf("errored file converting config to json: %v", err)
	}

	err = os.WriteFile(filename, config, 0644)
	if err != nil {
		return fmt.Errorf("failed to dump the json config to: %s, err: %v", filename, err)
	}

	return nil
}

func (p *Provider) Initialize() error {
	if p.ClusterName == "" {
		randPostFix := utils.RandString(6)
		p.ClusterName = "k8s-cluster-" + randPostFix
	}
	if p.BootstrapToken == "" {
		bootstrapToken, err := bootstraputil.GenerateBootstrapToken()
		if err != nil {
			return fmt.Errorf("failed to generate a random string, error: %v", err)
		}
		p.BootstrapToken = bootstrapToken
	}
	if p.KubeconfigPath == "" {
		p.KubeconfigPath = path.Join(p.ClusterName, "kubeconfig")
	}
	// Added an absolute path to behave ansible properly while copying back the content from remote machine
	var err error
	p.KubeconfigPath, err = filepath.Abs(p.KubeconfigPath)
	if err != nil {
		return fmt.Errorf("errored while getting absolute path for kubeconfig file")
	}
	return nil
}
